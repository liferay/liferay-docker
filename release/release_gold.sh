#!/bin/bash

source _liferay_common.sh

function check_usage {
	if [ -z "${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" ] || [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi
}

function copy_rc {
	if (ssh -i lrdcom-vm-1 root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}" | grep -q "${LIFERAY_RELEASE_VERSION}" &>/dev/null)
	then
		lc_log ERROR "Release was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/dxp/release-candidates/${LIFERAY_RELEASE_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" "/www/releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}"
}

function main {
	check_usage

	lc_time_run copy_rc
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=<timestamp> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_RC_BUILD_TIMESTAMP: The timestamp of the build to publish"
	echo "    LIFERAY_RELEASE_VERSION: The DXP version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_RC_BUILD_TIMESTAMP=1695892964 LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main