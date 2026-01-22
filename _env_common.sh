#!/bin/bash

function is_ci_slave {
	local slave_name=${1}

	if [ -z "${slave_name}" ]
	then
		slave_name=$(hostname)
	fi

	if [[ "${slave_name}" =~ ^test-[0-9]+-[0-9]+-[0-9]+$ ]]
	then
		return 0
	fi

	return 1
}

function is_release_slave {
	local slave_name=${1}

	if [ -z "${slave_name}" ]
	then
		slave_name=$(hostname)
	fi

	if [[ "${slave_name}" =~ ^release-slave-[1-4]$ ]]
	then
		return 0
	fi

	return 1
}