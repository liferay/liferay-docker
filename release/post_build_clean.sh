#!/bin/bash

source ./_liferay_common.sh

function main {
	lc_log INFO "Cleaning build."

	for dir in "logs-20*" "temp-*"
	do
		find . /opt/dev/projects/github/liferay-docker \
			-maxdepth 1 \
			-mtime +6 \
			-name "${dir}" \
			-type d \
			-exec rm --force --recursive {} \; &> /dev/null
	done

	local current_job=$(basename "${PWD}")

	if [ "${current_job}" == "build-release" ] ||
	   [ "${current_job}" == "build-release-nightly" ] ||
	   [ "${current_job}" == "release-gold" ]
	then
		docker system prune --all --force &> /dev/null

		rm --force --recursive downloads
		rm --force --recursive release/release-data
	elif [ "${current_job}" == "source-code-sharing" ]
	then
		rm --force --recursive narwhal/source_code_sharing/liferay-portal-ee
	fi
}

main