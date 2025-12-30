#!/bin/bash

source ../_liferay_common.sh

function main {
	while true
	do
		docker system prune --all --force &> /dev/null

		LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" LIFERAY_RELEASE_GIT_REF="master" LIFERAY_RELEASE_OUTPUT="nightly" LIFERAY_RELEASE_UPLOAD="true" ./build_release.sh

		if [ "${?}" -ne 0 ] && [ "${1}" == "--no-sleep" ]
		then
			lc_log ERROR "Nightly build failed."

			exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		if [ "${1}" == "--no-sleep" ]
		then
			break
		else
			sleep 1d
		fi
	done
}

main "${1}"