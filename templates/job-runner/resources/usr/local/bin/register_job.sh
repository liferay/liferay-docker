#!/bin/bash

function main {
	mkdir -p /opt/liferay/job-queue

	if [ ! -e "/opt/liferay/job-queue/${1}" ]
	then
		touch "/opt/liferay/job-queue/${1}"

		echo "Registering ${1}."
	else
		echo "Skipping ${1} because it is already registered."
	fi
}

main "${@}"
