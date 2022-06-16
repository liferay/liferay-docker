#!/bin/bash

function build_webserver {
	docker build templates/webserver --tag liferay-webserver:${LIFERAY_MANAGED_DXP_VERSION}
}

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "Set the version number of the generated images as the first parameter to build the images and configuration."
		echo ""
		echo "Example: ${0} 1.0.0"

		exit 1
	fi

	LIFERAY_MANAGED_DXP_VERSION=${1}

	check_utils docker
}

function check_utils {

	#
	# https://stackoverflow.com/a/677212
	#

	for util in "${@}"
	do
		command -v "${util}" >/dev/null 2>&1 || { echo >&2 "The utility ${util} is not installed."; exit 1; }
	done
}

function main {
	check_usage ${@}

	build_webserver
}

main ${@}