#!/bin/bash

function get_environment_type {
	local host=${1}

	if [ -z "${host}" ]
	then
		host=$(hostname)
	fi

	if [[ "${host}" =~ ^test-[0-9]+-[0-9]+-[0-9]+$ ]]
	then
		echo "ci_slave"
	elif [[ "${host}" =~ ^release-slave-[1-2]$ ]]
	then
		echo "release_slave"
	elif [[ "${host}" =~ ^liferay-* ]]
	then
		echo "local"
	else
		echo ""
	fi
}