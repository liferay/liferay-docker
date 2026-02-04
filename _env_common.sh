#!/bin/bash

function get_environment_type {
	local target_host=${1}

	if [ -z "${target_host}" ]
	then
		target_host=$(hostname)
	fi

	if [[ "${target_host}" =~ ^test-[0-9]+-[0-9]+-[0-9]+$ ]]
	then
		echo "ci_slave"
	elif [[ "${target_host}" =~ ^release-slave-[1-4]$ ]]
	then
		echo "release_slave"
	elif [[ "${target_host}" =~ ^liferay-* ]]
	then
		echo "local"
	fi
}