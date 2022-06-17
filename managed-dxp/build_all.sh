#!/bin/bash

function build_liferay_dxp {
	local ajp_port=$(get_config ".\"${SERVICE}\".ajp_port" 8009)
	local http_port=$(get_config ".\"${SERVICE}\".http_port" 8080)

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "         - TOMCAT_AJP_PORT=${ajp_port}"
	compose_add 1 "    image: liferay/dxp:7.2.10-dxp-18-d4.1.1-snapshot-20220617040326"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"${ajp_port}:${ajp_port}\""
	compose_add 1 "        - \"${http_port}:8080\""
}

function build_webserver {
	local balance_members=$(get_config ".\"${SERVICE}\".balance_members")

	docker build \
		--tag liferay-webserver:${VERSION} \
		templates/webserver

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "        - LIFERAY_BALANCE_MEMBERS=${balance_members}"
	compose_add 1 "    image: liferay-webserver:${VERSION}"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"80:80\""
}

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    SERVER_ID (optional): Set the name of the configuration you would like to use. If not set the hostname is used."
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

function compose_add {
	local line=""
	if [ ${1} -eq 0 ]
	then
		echo "${2}" >> ${COMPOSE_FILE}

		return 0
	fi

	for i in {1..${1}}
	do
		line="${line}    "
	done

	line="${line}${2}"

	echo "${line}" >> ${COMPOSE_FILE}
}

function create_compose_file {
	BUILD_DIR=builds/${VERSION}
	COMPOSE_FILE=${BUILD_DIR}/docker-compose.yml

	mkdir -p ${BUILD_DIR}

	if [ -e ${COMPOSE_FILE} ]
	then
		rm -f ${COMPOSE_FILE}
	fi

	echo "services:" >> ${COMPOSE_FILE}
}

function get_config {
	local yq_output=$(yq ${1} < ${CONFIG_FILE})

	if [ "${yq_output}" == "null" ]
	then
		echo ${2}
	else
		echo ${yq_output}
	fi
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
	if [ ! -n "${SERVER_ID}" ]
	then
		SERVER_ID=$(hostname)
	fi

	if [ -e config/${SERVER_ID}.yml ]
	then
		CONFIG_FILE=config/${SERVER_ID}.yml

		echo "Using configuration for server ${SERVER_ID}."
	else
		CONFIG_FILE=single_server.yml

		echo "Using the default, single server configuration."
	fi
}

main ${@}