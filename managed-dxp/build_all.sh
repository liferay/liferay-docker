#!/bin/bash

function build_liferay_dxp {
	echo "Building Liferay DXP as ${LIFERAY_SERVICE}."
}

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

	check_utils docker yq
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

	setup_configuration

	process_configuration
}

function process_configuration {
	for service in $(yq '' < ${LIFERAY_MANAGED_DXP_CONFIG} | grep -v '  .*' | sed 's/://')
	do
		local service_image=$(yq ".\"$service\".image" < ${LIFERAY_MANAGED_DXP_CONFIG})

		LIFERAY_SERVICE=${service}

		build_${service_image}
	done
}

function setup_configuration {
	if [ -e /etc/liferay-managed-dxp.yaml ]
	then
		LIFERAY_MANAGED_DXP_CONFIG=/etc/liferay-managed-dxp.yml
	else
		LIFERAY_MANAGED_DXP_CONFIG=single_server.yml
	fi
}

main ${@}