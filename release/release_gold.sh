#!/bin/bash

source _liferay_common.sh
source _product_info_json.sh
source _promotion.sh
source _publishing.sh
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

	_PRODUCT_VERSION="${LIFERAY_RELEASE_VERSION}"

	_ARTIFACT_RC_VERSION="${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_RELEASE_ROOT_DIR="${PWD}"

	_PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function invoke_github_api {
	local curl_response=$(\
		curl \
			"https://api.github.com/repos/liferay/${1}" \
			--data "${2}" \
			--fail \
			--header "Accept: application/vnd.github+json" \
			--header "Authorization: Bearer ${LIFERAY_RELEASE_GITHUB_PAT}" \
			--header "X-GitHub-Api-Version: 2022-11-28" \
			--include \
			--max-time 10 \
			--request POST \
			--retry 3 \
			--silent)

	if [ $(echo "${curl_response}" | awk '/^HTTP/{print $2}') -ne 201 ]
	then
		lc_log ERROR "Unable to invoke GitHub API:"
		lc_log ERROR "${curl_response}"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function main {
	check_usage

	check_supported_versions

	lc_time_run promote_packages

	lc_time_run tag_release

	promote_boms

	if [[ ! $(echo "${_PRODUCT_VERSION}" | grep "q") ]] &&
	   [[ ! $(echo "${_PRODUCT_VERSION}" | grep "7.4") ]]
	then
		lc_log INFO "Do not update product_info.json for quarterly and 7.4 releases."

		lc_time_run generate_product_info_json

		lc_time_run upload_product_info_json
	fi

	lc_time_run generate_releases_json

	lc_time_run upload_releases_json

	lc_time_run testing_boms

	#lc_time_run upload_to_docker_hub
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_GITHUB_PAT (optional): GitHub personal access token used to tag releases"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD (optional): Nexus user's password"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_USER (optional): Nexus user with the right to upload BOM files"
	echo "    LIFERAY_RELEASE_PRODUCT_NAME (optional): Set to \"portal\" for CE. The default is \"DXP\"."
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_VERSION: DXP version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function promote_boms {
	lc_time_run prepare_poms_for_promotion xanadu

	lc_time_run prepare_api_jars_for_promotion xanadu

	lc_time_run upload_boms liferay-public-releases
}

function promote_packages {
	if (ssh root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}" | grep -q "${_PRODUCT_VERSION}" &>/dev/null)
	then
		lc_log ERROR "Release was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_ARTIFACT_RC_VERSION}" "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}"
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

	invoke_github_api "${repository}/git/tags" "${tag_data}"

	if [ $? -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
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

	invoke_github_api "${repository}/git/refs" "${ref_data}"

	if [ $? -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function testing_boms {
	if [ ! -d "${_RELEASE_ROOT_DIR}/temp_dir_boms" ]
	then
		mkdir -p "${_RELEASE_ROOT_DIR}/temp_dir_boms"
	fi

	lc_cd "${_RELEASE_ROOT_DIR}/temp_dir_boms"

	if [[ "${_PRODUCT_VERSION}" == *q* ]]
	then
		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}"
	else
		local product_group_version=$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2)

		local product_version_suffix=$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2)

		blade init -v "${LIFERAY_RELEASE_PRODUCT_NAME}-${product_group_version}-${product_version_suffix}"
	fi

	export LIFERAY_RELEASES_MIRRORS="https://releases.liferay.com"

	sed -i "s/version: \"10.1.0\"/version: \"10.1.2\"/" "${_RELEASE_ROOT_DIR}/temp_dir_boms/settings.gradle"

	if [ -f "${HOME}/.liferay/workspace/releases.json" ]
	then
		rm -f "${HOME}/.liferay/workspace/releases.json"
	fi

	local modules=("api" "mvc-portlet")

	for module in "${modules[@]}"
	do
		blade create -t "${module}" "test-${module}"

		local build_result=$(blade gw build)

		if [[ "${build_result}" == *"BUILD SUCCESSFUL"* ]]
		then
			lc_log INFO "The BOMs for the module ${module} were successfully tested."
		else
			lc_log ERROR "The BOMs for the module ${module} were generated incorrectly."

			break
		fi
	done

	lc_cd "${_RELEASE_ROOT_DIR}"

	pgrep --full --list-name temp_dir_boms | awk '{print $1}' | xargs -r kill -9

	rm -fr "${_RELEASE_ROOT_DIR}/temp_dir_boms"

	if [[ "${build_result}" != *"BUILD SUCCESSFUL"* ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

main