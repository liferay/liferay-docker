#!/bin/bash

source _liferay_common.sh

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "<version>: version number of Apache Tomcat (e.g. 9.0.97)."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_full_version {
	if [[ "${1}" == "9.0"* ]]
	then
		echo "9.0.100"
	else
		echo "Unable to get full version for ${1}."

		exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
	fi
}

function main {
	check_usage "${@}"

	get_full_version "${@}"
}

main "${@}"