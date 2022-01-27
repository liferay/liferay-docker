#!/bin/bash

function init {
	JOB=${1}

	mkdir -p /opt/liferay/job-queue
}

function main {
	init ${1}

	register
}

function register {
	#
	# Important: Do not retouch when file exists as jobs are executed based on modification date
	#

	if [ ! -e "/opt/liferay/job-queue/${JOB}" ]
	then
		touch "/opt/liferay/job-queue/${JOB}"

		echo "Registering ${JOB}"
	else
		echo "Skipping registering ${JOB} as it's already in the queue."
	fi
}

main "${@}"