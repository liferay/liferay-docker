#!/bin/bash

source ./_common.sh

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "This script requires the first parameter to be set to the major and minor version of the Patching Tool (e.g. 2.0)."

		exit 1
	fi
}

function get_full_version {
	if [ "${1}" == "1.0" ]
	then
		echo "1.0.24"
	elif [ "${1}" == "3.0" ]
	then
		echo "2.0.15"
	elif [ "${1}" == "3.0" ]
	then
		echo "3.0.24"
	else
		echo "Unable to get full version for ${1}."

		exit 2
	fi
}

function main {
	check_usage ${@}

	get_full_version ${@}
}

main ${@}