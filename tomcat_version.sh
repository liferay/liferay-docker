#!/bin/bash

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "This script requires the first parameter to be set to the version of the Apache Tomcat (e.g. 9.0.97)."

		exit 1
	fi
}

function get_full_version {
	if [[ "${1}" == "9.0"* ]]
	then
		echo "9.0.100"
	else
		echo "Unable to get full version for ${1}."

		exit 2
	fi
}

function main {
	check_usage "${@}"

	get_full_version "${@}"
}

main "${@}"