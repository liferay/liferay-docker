#!/bin/bash

function main {
	while true
	do
		LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" LIFERAY_RELEASE_GIT_REF="master" LIFERAY_RELEASE_OUTPUT="nightly" LIFERAY_RELEASE_UPLOAD="true" ./build_release.sh

		if [ "${1}" == "--no-sleep" ]
		then
			break
		else
			sleep 1d
		fi
	done
}

main "${1}"