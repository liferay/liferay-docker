#!/bin/bash

source _liferay_common.sh
source _product_info_json.sh
source _promotion.sh
source _publishing.sh

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

	promote_boms

	update_product_info_json
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD: Nexus user's password"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_USER: Nexus user with the right to upload BOM files"
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
	if (ssh -i lrdcom-vm-1 root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_DXP_VERSION}" | grep -q "${_DXP_VERSION}" &>/dev/null)
	then
		lc_log ERROR "Release was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_ARTIFACT_RC_VERSION}" "/www/releases.liferay.com/dxp/${_DXP_VERSION}"
}

function update_product_info_json {
	lc_time_run validate_version_for_product_info_json || return 0

	lc_time_run get_file_product_info_json

	lc_time_run get_file_release_properties

	lc_time_run generate_product_info_json

	lc_time_run upload_product_info_json
}

main