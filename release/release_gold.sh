#!/bin/bash

source _liferay_common.sh
source _product_info_json.sh
source _promotion.sh
source _publishing.sh
source _releases_json.sh

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

function main {
	check_usage

	lc_time_run promote_packages

	lc_time_run tag_release

	promote_boms

	lc_time_run generate_product_info_json

	#lc_time_run upload_product_info_json

	lc_time_run regenerate_releases_json

	lc_time_run upload_releases_json
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

	ssh root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_ARTIFACT_RC_VERSION}" "/www/releases.liferay.com/dxp/${_PRODUCT_VERSION}"
}

function tag_release {
	if [ -z "${LIFERAY_RELEASE_GITHUB_PAT}" ]
	then
		lc_log INFO "Set the environment variable \"LIFERAY_RELEASE_GITHUB_PAT\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local repository=liferay-portal-ee

	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "portal" ]
	then
		repository=liferay-portal
	fi

	if (! curl
			"https://api.github.com/repos/liferay/${repository}/git/tags" \
			--data-raw '
				{
					"message": "",
					"object": "$(lc_get_property release-data/release.properties git.hash.liferay-portal-ee)",
					"tag": "${LIFERAY_RELEASE_VERSION}",
					"type": "commit"
				}' \
			--fail \
			--header "Accept: application/vnd.github+json" \
			--header "Authorization: Bearer ${LIFERAY_RELEASE_GITHUB_PAT}" \
			--header "X-GitHub-Api-Version: 2022-11-28" \
			--max-time 10 \
			--request POST \
			--retry 3 \
			--silent)
	then
		lc_log ERROR "Unable to tag release."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

main