#!/bin/bash

source _liferay_common.sh
source _promotion.sh
source _publishing.sh

function check_usage {
	if [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi

	_ARTIFACT_RC_VERSION="${LIFERAY_RELEASE_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"
	_DXP_VERSION="${LIFERAY_RELEASE_VERSION}"

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_PROMOTION_DIR="${PWD}/release-data/promotion/files"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
	LIFERAY_RELEASE_PUBLISH_BOMS="${LIFERAY_RELEASE_PUBLISH_BOMS:-true}"
	LIFERAY_RELEASE_PUBLISH_PACKAGES="${LIFERAY_RELEASE_PUBLISH_PACKAGES:-true}"
}

function copy_rc {
	if [ "${LIFERAY_RELEASE_PUBLISH_PACKAGES}" = "true" ]
	then
		if (ssh -i lrdcom-vm-1 root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}" | grep -q "${LIFERAY_RELEASE_VERSION}" &>/dev/null)
		then
			lc_log ERROR "Release was already published."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		ssh -i lrdcom-vm-1 root@lrdcom-vm-1 \
			cp -a \
					"/www/releases.liferay.com/dxp/release-candidates/${LIFERAY_RELEASE_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" \
					"/www/releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}"
	else
		lc_log DEBUG "Skipping packages publishing in production."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function main {
	check_usage

	lc_time_run prepare_poms_for_promotion xanadu

	lc_time_run prepare_api_jars_for_promotion xanadu

	lc_time_run upload_boms liferay-public-releases

	lc_time_run copy_rc
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD: Nexus user's password"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_USER: Nexus user with the right to upload BOM files"
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: Timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_PUBLISH_BOMS: Publish BOMs in production (default: true)"
	echo "    LIFERAY_RELEASE_PUBLISH_PACKAGES: Publish packages in production (default: true)"
	echo "    LIFERAY_RELEASE_VERSION: DXP version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main