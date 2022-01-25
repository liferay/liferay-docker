#!/bin/bash

function init {
	JOB_NAME=${1}

	mkdir -p /opt/liferay/connector-queue
}

function main {
	init ${1}

	register
}

function register {
	#
	# Important: Do not retouch when file exists as jobs are executed based on modification date
	#

	if [ ! -e "/opt/liferay/connector-queue/${JOB_NAME}" ]
	then
		touch "/opt/liferay/connector-queue/${JOB_NAME}"

		echo "Registering ${JOB_NAME}"
	else
		echo "Skipping registering ${JOB_NAME} as it's already in the queue."
	fi
}

main "${@}"