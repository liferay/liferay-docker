#!/bin/bash

function build_liferay_dxp {
	echo ""
}

function build_webserver {
	docker build templates/webserver --tag liferay-webserver:${VERSION}
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

	VERSION=${1}

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

function create_compose_file {
	OUTPUT_DIR=output/${VERSION}
	COMPOSE_FILE=${OUTPUT_DIR}/docker-compose.yml

	mkdir -p $(dirname "${COMPOSE_FILE}")

	echo "services:" >> ${COMPOSE_FILE}
}

function main {
	check_usage ${@}

	setup_configuration

	create_compose_file

	process_configuration
}

function process_configuration {
	for SERVICE in $(yq '' < ${CONFIG_FILE} | grep -v '  .*' | sed 's/://')
	do
		local service_template=$(yq ".\"${SERVICE}\".template" < ${CONFIG_FILE})

		echo "Building ${SERVICE}."

		build_${service_template}
	done
}

function setup_configuration {
	if [ -e /etc/liferay-managed-dxp.yaml ]
	then
		CONFIG_FILE=/etc/liferay-managed-dxp.yml
	else
		CONFIG_FILE=single_server.yml
	fi
}

main ${@}