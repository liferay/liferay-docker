#!/bin/bash

function init {
	. /usr/local/bin/set_java_version.sh

	mkdir -p /opt/liferay/job-queue
}

function main {
	init

	register_crontab

	cron

	run_jobs
}

function register_crontab {
	if [ ! -e /mnt/liferay/job-crontab ]
	then
		echo "The file /mnt/liferay/job-crontab does not exist."

		exit 2
	fi

	(
		crontab -l 2>/dev/null

		cat /mnt/liferay/job-crontab | envsubst
	) | crontab -

	echo "Registered crontab: "

	crontab -l

	echo ""
}

function run_jobs {
	while true
	do
		if [ $(ls /opt/liferay/job-queue | wc -l) -gt 0 ]
		then
			local job=$(ls -tr /opt/liferay/job-queue | head -n 1)

			rm "/opt/liferay/job-queue/${job}"

			job_wrapper.sh "${job}"
		else
			sleep 10
		fi
	done
}

main
