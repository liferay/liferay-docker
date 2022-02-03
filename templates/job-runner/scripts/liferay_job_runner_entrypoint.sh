#!/bin/bash

function init {
	. /usr/local/bin/set_java_version.sh

	mkdir -p /opt/liferay/job-queue

	cron
}

function main {
	init

	register_crontab

	run_jobs
}

function register_crontab {
	if [ ! -e /mnt/liferay/job-runner-crontab ]
	then
		echo "The job-runner-crontab file is not available in the /mnt/liferay/ directory."

		exit 2
	fi

	(
		crontab -l 2>/dev/null
		cat /mnt/liferay/job-runner-crontab
	) | crontab -

	echo "The following crontab is installed:"
	cat /mnt/liferay/job-runner-crontab
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