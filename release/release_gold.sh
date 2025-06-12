#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ./_git.sh
source ./_github.sh
source ./_jira.sh
source ./_product.sh
source ./_product_info_json.sh
source ./_promotion.sh
source ./_releases_json.sh

function add_property {
	local new_key="${1}"
	local new_value="${2}"
	local search_key="${3}"

	sed -i "/${search_key}/a\	\\${new_key}=${new_value}" "build.properties"
}

function check_supported_versions {
	local supported_version="$(get_product_group_version)"

	if [ -z $(grep "${supported_version}" "${_RELEASE_ROOT_DIR}"/supported-"${LIFERAY_RELEASE_PRODUCT_NAME}"-versions.txt) ]
	then
		lc_log ERROR "Unable to find ${supported_version} in supported-${LIFERAY_RELEASE_PRODUCT_NAME}-versions.txt."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_usage {
	if [ -z "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" ] || [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
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

	_PROJECTS_DIR="/opt/dev/projects/github"

	if [ ! -d "${_PROJECTS_DIR}" ]
	then
		_PROJECTS_DIR="${_RELEASE_ROOT_DIR}/dev/projects"
	fi

	_PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function get_tag_name {
	if (is_ga_release || is_u_release)
	then
		echo "${_PRODUCT_VERSION}"
	elif is_quarterly_release
	then
		echo "${_ARTIFACT_VERSION}"
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

	if (! is_quarterly_release && ! is_7_4_release)
	then
		lc_log INFO "Do not update product_info.json for quarterly and 7.4 releases."

		lc_time_run generate_product_info_json

		lc_time_run upload_product_info_json
	fi

	lc_time_run generate_releases_json

	lc_time_run test_boms

	lc_time_run reference_new_releases

	lc_time_run add_patcher_project_version

	#if [ -d "${_RELEASE_ROOT_DIR}/dev/projects" ]
	#then
	#	lc_background_run clone_repository liferay-portal-ee

	#	lc_wait
	#fi

	#lc_time_run clean_portal_repository

	#lc_time_run prepare_next_release_branch

	#lc_time_run update_release_info_date

	#lc_time_run upload_to_docker_hub
}

function prepare_next_release_branch {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep -i "true") ] ||
	   ! is_quarterly_release
	then
		lc_log INFO "Skipping the preparation of the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		rm -fr releases.json

		LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/releases.json" releases.json
	fi

	local product_group_version="$(get_product_group_version)"

	local latest_quarterly_product_version="$(\
		jq -r ".[] | \
			select(.productGroupVersion == \"${product_group_version}\" and .promoted == \"true\") | \
			.targetPlatformVersion" releases.json)"

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		rm -fr releases.json
	fi

	if [ "${_PRODUCT_VERSION}" != "${latest_quarterly_product_version}" ]
	then
		lc_log INFO "The ${_PRODUCT_VERSION} version is not the latest quarterly release. Skipping the preparation of the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local quarterly_release_branch="release-${product_group_version}"

	prepare_branch_to_commit "${_PROJECTS_DIR}/liferay-portal-ee" "liferay-portal-ee" "${quarterly_release_branch}"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to prepare the next release branch."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	else
		local next_release_patch_version=$(get_release_patch_version)

		next_release_patch_version=$((next_release_patch_version + 1))

		if [[ "${_PRODUCT_VERSION}" == *q1* ]]
		then
			if [[ "$(get_release_year)" -ge 2025 ]]
			then
				next_release_patch_version="${next_release_patch_version} LTS"
			fi
		fi

		sed -i \
			-e "s/release.info.version.display.name\[master-private\]=.*/release.info.version.display.name[master-private]=${product_group_version^^}.${next_release_patch_version}/" \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties"

		sed -i \
			-e "s/release.info.version.display.name\[release-private\]=.*/release.info.version.display.name[release-private]=${product_group_version^^}.${next_release_patch_version}/" \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties"

		if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
		then
			commit_to_branch_and_send_pull_request \
				"${_PROJECTS_DIR}/liferay-portal-ee/release.properties" \
				"Prepare ${product_group_version}.${next_release_patch_version}" \
				"${quarterly_release_branch}" \
				"brianchandotcom/liferay-portal-ee" \
				"Prep next"

			local exit_code="${?}"

			if [ "${exit_code}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
			then
				lc_log ERROR "Unable to commit to the release branch."
			else
				lc_log INFO "The next release branch was prepared successfully."
			fi

			delete_temp_branch "liferay-portal-ee"

			return "${exit_code}"
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
	echo "    LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH: Set to \"true\" to prepare the next release branch. The default is \"false\"."
	echo "    LIFERAY_RELEASE_PRODUCT_NAME (optional): Set to \"portal\" for CE. The default is \"DXP\"."
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_VERSION: DXP or portal version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH=true LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function reference_new_releases {
	if ! is_quarterly_release
	then
		lc_log INFO "Skipping the update to the references in the liferay-jenkins-ee repository."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local issue_key=""

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		issue_key="$(\
			add_jira_issue \
				"60a3f462391e56006e6b661b" \
				"Release Tester" \
				"Task" \
				"LRCI" \
				"Add release references for ${_PRODUCT_VERSION}" \
				"customfield_10001" \
				"04c03e90-c5a7-4fda-82f6-65746fe08b83")"

		if [ "${issue_key}" == "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to create a Jira issue to add release references for ${_PRODUCT_VERSION}."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		prepare_branch_to_commit "${_PROJECTS_DIR}/liferay-jenkins-ee/commands" "liferay-jenkins-ee"
	fi

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to prepare the next release references branch."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local base_url="http://mirrors.lax.liferay.com/releases.liferay.com"

	local latest_quarterly_release="false"

	local product_group_version="$(get_product_group_version)"

	local previous_product_version="$(\
		grep "portal.latest.bundle.version\[${product_group_version}" \
			"build.properties" | \
			tail -1 | \
			cut -d '=' -f 2)"

	if [ -z "${previous_product_version}" ]
	then
		latest_quarterly_release="true"
		previous_product_version="$(grep "portal.latest.bundle.version\[master\]=" "build.properties" | cut -d '=' -f 2)"
	fi

	for component in osgi sql tools
	do
		add_property \
			"portal.${component}.zip.url\[${_PRODUCT_VERSION}\]" \
			"${base_url}/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-${component}-${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}.zip" \
			"portal.${component}.zip.url\[${previous_product_version}\]="
	done

	add_property \
		"plugins.war.zip.url\[${_PRODUCT_VERSION}\]" \
		"http://release-1/1/userContent/liferay-release-tool/7413/plugins.war.latest.zip" \
		"plugins.war.zip.url\[${previous_product_version}\]="

	add_property \
		"	portal.bundle.tomcat\[${_PRODUCT_VERSION}\]" \
		"${base_url}/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}.7z" \
		"portal.bundle.tomcat\[${previous_product_version}\]="

	add_property \
		"portal.license.url\[${_PRODUCT_VERSION}\]" \
		"http://www.liferay.com/licenses/license-portaldevelopment-developer-cluster-7.0de-liferaycom.xml" \
		"portal.license.url\[${previous_product_version}\]="

	add_property \
		"portal.version.latest\[${_PRODUCT_VERSION}\]" \
		"${_PRODUCT_VERSION}" \
		"portal.version.latest\[${previous_product_version}\]="

	add_property \
		"portal.war.url\[${_PRODUCT_VERSION}\]" \
		"${base_url}/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}.war" \
		"portal.war.url\[${previous_product_version}\]="

	add_property \
		"portal.latest.bundle.version\[${_PRODUCT_VERSION}\]" \
		"${_PRODUCT_VERSION}" \
		"portal.latest.bundle.version\[${previous_product_version}\]="

	local latest_product_group_version="$(\
		grep "portal.latest.bundle.version\[master\]=" \
			"build.properties" | \
			cut -d '=' -f 2 | \
			cut -d '.' -f 1,2)"

	if [ "${product_group_version}" == "${latest_product_group_version}" ] || [ "${latest_quarterly_release}" == "true" ] 
	then
		replace_property \
			"portal.latest.bundle.version\[master\]" \
			"${_PRODUCT_VERSION}" \
			"portal.latest.bundle.version\[master\]=${previous_product_version}"
	fi

	local previous_quarterly_release_branch="$(\
		grep "portal.latest.bundle.version" \
			"build.properties" | \
			tail -1 | \
			cut -d '[' -f 2 | \
			cut -d ']' -f 1)"

	local quarterly_release_branch="release-$(get_product_group_version)"

	if [ "${latest_quarterly_release}" == "false" ]
	then
		replace_property \
			"portal.latest.bundle.version\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.latest.bundle.version\[${quarterly_release_branch}\]=${previous_product_version}"

		replace_property \
			"portal.version.latest\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.version.latest\[${quarterly_release_branch}\]=${previous_product_version}"
	else
		add_property \
			"portal.latest.bundle.version\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.latest.bundle.version\[${previous_quarterly_release_branch}\]="

		add_property \
			"portal.version.latest\[${quarterly_release_branch}\]" \
			"${_PRODUCT_VERSION}" \
			"portal.version.latest\[${previous_quarterly_release_branch}\]="
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		commit_to_branch_and_send_pull_request \
			"${_PROJECTS_DIR}/liferay-jenkins-ee/commands/build.properties" \
			"${issue_key} Add release references for ${_PRODUCT_VERSION}" \
			"master" \
			"pyoo47/liferay-jenkins-ee" \
			"${issue_key} Add release references for ${_PRODUCT_VERSION}."

		local exit_code="${?}"

		if [ "${exit_code}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to send pull request with references to the next release."
		else
			lc_log INFO "Pull request with references to the next release was sent successfully."

			local pull_request_url="$(\
				gh pr view liferay-release:${issue_key} \
					--jq ".url" \
					--json "url" \
					--repo "pyoo47/liferay-jenkins-ee")"

			add_jira_issue_comment "Related pull request: ${pull_request_url}" "${issue_key}"
		fi

		delete_temp_branch "liferay-jenkins-ee"

		return "${exit_code}"
	fi
}

function replace_property {
	local new_key="${1}"
	local new_value="${2}"
	local search_key="${3}"

	sed -i "s/${search_key}/${new_key}=${new_value}/" "build.properties"
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

	if is_portal_release
	then
		repository=liferay-portal
	fi

	local tag_name="$(get_tag_name)"

	for repository_owner in brianchandotcom liferay
	do
		local tag_data=$(
			cat <<- END
			{
				"message": "",
				"object": "${git_hash}",
				"tag": "${tag_name}",
				"type": "commit"
			}
			END
		)

		if [ $(invoke_github_api_post "${repository_owner}" "${repository}/git/tags" "${tag_data}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			lc_log ERROR "Unable to create tag ${tag_name} in ${repository_owner}/${repository}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		local ref_data=$(
			cat <<- END
			{
				"message": "",
				"ref": "refs/tags/${tag_name}",
				"sha": "${git_hash}"
			}
			END
		)

		if [ $(invoke_github_api_post "${repository_owner}" "${repository}/git/refs" "${ref_data}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			lc_log ERROR "Unable to create tag reference for ${tag_name} in ${repository_owner}/${repository}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	done

	if is_7_4_u_release
	then
		local temp_branch="release-$(echo "${_PRODUCT_VERSION}" | sed -r "s/-u/\./")"

		if [ $(invoke_github_api_delete "brianchandotcom" "${repository}/git/refs/heads/${temp_branch}") -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			lc_log ERROR "Unable to delete temp branch ${temp_branch} in ${LIFERAY_RELEASE_REPOSITORY_OWNER}/${repository}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi
}

function test_boms {
	if is_7_4_u_release
	then
		lc_log INFO "Skipping test BOMs for ${_PRODUCT_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm -f "${HOME}/.liferay/workspace/releases.json"

	mkdir -p "temp_dir_test_boms"

	lc_cd "temp_dir_test_boms"

	if is_quarterly_release
	then
		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}"
	else
		local product_group_version="$(get_product_group_version)"
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
	if ! is_quarterly_release ||
	   [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep -i "true") ] ||
	   [[ "$(get_release_patch_version)" -eq 0 ]] ||
	   [[ "$(get_release_year)" -lt 2024 ]]
	then
		lc_log INFO "Skipping the release info update."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local product_group_version="$(get_product_group_version)"

	local quarterly_release_branch="release-${product_group_version}"

	prepare_branch_to_commit "${_PROJECTS_DIR}/liferay-portal-ee" "liferay-portal-ee" "${quarterly_release_branch}"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to update the release date."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	sed -i \
		-e "s/release.info.date=.*/release.info.date=$(date -d "next monday" +"%B %-d, %Y")/" \
		release.properties

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		commit_to_branch_and_send_pull_request \
			"${_PROJECTS_DIR}/liferay-portal-ee/release.properties" \
			"Update the release info date for ${_PRODUCT_VERSION}" \
			"${quarterly_release_branch}" \
			"brianchandotcom/liferay-portal-ee" \
			"Prep next"

		local exit_code="${?}"

		if [ "${exit_code}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to commit to the release branch."
		else
			lc_log INFO "The release date was updated successfully."
		fi

		delete_temp_branch "liferay-portal-ee"

		return "${exit_code}"
	fi
}

main "${@}"