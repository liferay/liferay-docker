#!/bin/bash

source ../_liferay_common.sh
source _git.sh
source _github.sh
source _product.sh
source _product_info_json.sh
source _promotion.sh
source _releases_json.sh

function check_supported_versions {
	local supported_version="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	if [ -z $(grep "${supported_version}" "${_RELEASE_ROOT_DIR}"/supported-"${LIFERAY_RELEASE_PRODUCT_NAME}"-versions.txt) ]
	then
		lc_log ERROR "Unable to find ${supported_version} in supported-${LIFERAY_RELEASE_PRODUCT_NAME}-versions.txt."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_usage {
	if [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi

	if [ -z "${LIFERAY_RELEASE_PRODUCT_NAME}" ]
	then
		LIFERAY_RELEASE_PRODUCT_NAME=dxp
	fi

	set_product_version "${LIFERAY_RELEASE_VERSION}" "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_RELEASE_ROOT_DIR="${PWD}"

	_BASE_DIR="$(dirname "${_RELEASE_ROOT_DIR}")"
	_PROJECTS_DIR="${_RELEASE_ROOT_DIR}/dev/projects"
	_PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function commit_to_branch_and_send_pull_request {
	git add "${1}"

	git commit -m "${2}"

	git push -f origin "${3}"

	gh pr create \
		--base "${3}" \
		--body "Created by liferay-docker/release/release_gold.sh." \
		--repo brianchandotcom/liferay-portal-ee \
		--title "${4}"

	if [ "${?}" -ne 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function main {
	if [[ " ${@} " =~ " --test " ]]
	then
		return
	fi

	check_usage

	check_supported_versions

	init_gcs

	lc_time_run promote_packages

	lc_time_run tag_release

	promote_boms xanadu

	if [[ ! $(echo "${_PRODUCT_VERSION}" | grep "q") ]] &&
	   [[ ! $(echo "${_PRODUCT_VERSION}" | grep "7.4") ]]
	then
		lc_log INFO "Do not update product_info.json for quarterly and 7.4 releases."

		lc_time_run generate_product_info_json

		lc_time_run upload_product_info_json
	fi

	lc_time_run generate_releases_json

	lc_time_run test_boms

	lc_time_run add_patcher_project_version

	lc_background_run clone_repository liferay-portal-ee

	lc_wait

	lc_time_run clean_portal_repository

	lc_time_run prepare_next_release_branch

	lc_time_run update_release_info_date

	#lc_time_run upload_to_docker_hub
}

function prepare_branch_to_commit {
	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	git restore .

	git checkout master &> /dev/null

	git branch --delete --force "${1}" &> /dev/null

	git fetch --no-tags upstream "${1}":"${1}" &> /dev/null

	git checkout "${1}" &> /dev/null

	if [ "$(git rev-parse --abbrev-ref HEAD 2> /dev/null)" != "${1}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function prepare_next_release_branch {
	if [[ "${_PRODUCT_VERSION}" != *q* ]]
	then
		lc_log INFO "Skipping the preparation of the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm -fr releases.json

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/releases.json" releases.json

	local product_group_version="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	local latest_quarterly_product_version="$(\
		jq -r ".[] | \
			select(.productGroupVersion == \"${product_group_version}\" and .promoted == \"true\") | \
			.targetPlatformVersion" releases.json)"

	rm -fr releases.json

	if [ "${_PRODUCT_VERSION}" != "${latest_quarterly_product_version}" ]
	then
		lc_log INFO "The ${_PRODUCT_VERSION} version is not the latest quartely release. Skipping the preparation of the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local quarterly_release_branch_name="release-${product_group_version}"

	prepare_branch_to_commit "${quarterly_release_branch_name}"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to prepare the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	else
		local next_project_version_suffix="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 3)"

		next_project_version_suffix=$((next_project_version_suffix + 1))

		sed -i \
			-e "s/release.info.version.display.name\[master-private\]=.*/release.info.version.display.name[master-private]=${product_group_version^^}.${next_project_version_suffix}/" \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties"

		sed -i \
			-e "s/release.info.version.display.name\[release-private\]=.*/release.info.version.display.name[release-private]=${product_group_version^^}.${next_project_version_suffix}/" \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties"

		if [[ ! " ${@} " =~ " --test " ]]
		then
			commit_to_branch_and_send_pull_request \
				"${_PROJECTS_DIR}/liferay-portal-ee/release.properties" \
				"Prepare ${quarterly_release_branch_name}" \
				"${quarterly_release_branch_name}" \
				"Prep next"

			if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
			then
				lc_log ERROR "Unable to commit to the release branch."

				return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
			else
				lc_log INFO "The next release branch was prepared successfully."
			fi
		fi
	fi
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_GCS_TOKEN (optional): *.json file containing the token to authenticate with Google Cloud Storage"
	echo "    LIFERAY_RELEASE_GITHUB_PAT (optional): GitHub personal access token used to tag releases"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD (optional): Nexus user's password"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_USER (optional): Nexus user with the right to upload BOM files"
	echo "    LIFERAY_RELEASE_PATCHER_PORTAL_EMAIL_ADDRESS: Email address to the release team's Liferay Patcher user"
	echo "    LIFERAY_RELEASE_PATCHER_PORTAL_PASSWORD: Password to the release team's Liferay Patcher user"
	echo "    LIFERAY_RELEASE_PRODUCT_NAME (optional): Set to \"portal\" for CE. The default is \"DXP\"."
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_REPOSITORY_OWNER (optional): Set to \"EnterpriseReleaseHU\" for development. The default is \"liferay\"."
	echo "    LIFERAY_RELEASE_VERSION: DXP or portal version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function tag_release {
	if [ -z "${LIFERAY_RELEASE_GITHUB_PAT}" ]
	then
		lc_log INFO "Set the environment variable \"LIFERAY_RELEASE_GITHUB_PAT\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local release_properties_file=$(lc_download "https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/release.properties")

	if [ $? -ne 0 ]
	then
		lc_log ERROR "Unable to download release.properties."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local git_hash=$(lc_get_property "${release_properties_file}" git.hash.liferay-portal-ee)

	if [ -z "${git_hash}" ]
	then
		lc_log ERROR "Unable to get property \"git.hash.liferay-portal-ee.\""

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local repository=liferay-portal-ee

	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "portal" ]
	then
		repository=liferay-portal
	fi

	local tag_data=$(
		cat <<- END
		{
			"message": "",
			"object": "${git_hash}",
			"tag": "${_PRODUCT_VERSION}",
			"type": "commit"
		}
		END
	)

	if [ $(invoke_github_api_post "${repository}/git/tags" "${tag_data}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local ref_data=$(
		cat <<- END
		{
			"message": "",
			"ref": "refs/tags/${_PRODUCT_VERSION}",
			"sha": "${git_hash}"
		}
		END
	)

	if [ $(invoke_github_api_post "${repository}/git/refs" "${ref_data}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function test_boms {
	if [[ "${_PRODUCT_VERSION}" == 7.4.*-u* ]]
	then
		lc_log INFO "Skipping test BOMs for ${_PRODUCT_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm -f "${HOME}/.liferay/workspace/releases.json"

	mkdir -p "temp_dir_test_boms"

	lc_cd "temp_dir_test_boms"

	if [[ "${_PRODUCT_VERSION}" == *q* ]]
	then
		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}"
	else
		local product_group_version=$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)
		local product_version_suffix=$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2)

		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${product_group_version}-${product_version_suffix}"
	fi

	export LIFERAY_RELEASES_MIRRORS="https://releases.liferay.com"

	sed -i "s/version: \"10.1.0\"/version: \"10.1.2\"/" "temp_dir_test_boms/settings.gradle"

	for module in api mvc-portlet
	do
		blade create -t "${module}" "test-${module}"

		local build_result=$(blade gw build)

		if [[ "${build_result}" == *"BUILD SUCCESSFUL"* ]]
		then
			lc_log INFO "The BOMs for the module ${module} were successfully tested."
		else
			lc_log ERROR "The BOMs for the module ${module} were incorrectly generated."

			break
		fi
	done

	lc_cd ".."

	pgrep --full --list-name temp_dir_test_boms | awk '{print $1}' | xargs --no-run-if-empty kill -9

	rm -fr "temp_dir_test_boms"

	if [[ "${build_result}" != *"BUILD SUCCESSFUL"* ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function update_release_info_date {
	if [[ "${_PRODUCT_VERSION}" != *q* ]] ||
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 3)" -eq 0 ]] ||
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1)" -lt 2024 ]]
	then
		lc_log INFO "Skipping the release info update."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local product_group_version="$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)"

	local quarterly_release_branch_name="release-${product_group_version}"

	prepare_branch_to_commit "${quarterly_release_branch_name}"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to update the release date."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	sed -i \
		-e "s/release.info.date=.*/release.info.date=$(date -d "next monday" +"%B %-d, %Y")/" \
		release.properties

	if [[ ! " ${@} " =~ " --test " ]]
	then
		commit_to_branch_and_send_pull_request \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties" \
			"Update the release info date for ${_PRODUCT_VERSION}" \
			"${quarterly_release_branch_name}" \
			"Prep next"

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to commit to the release branch."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		else
			lc_log INFO "The release date was updated successfully."
		fi
	fi
}

main "${@}"