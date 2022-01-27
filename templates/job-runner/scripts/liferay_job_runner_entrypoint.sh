#!/bin/bash

function init {
	mkdir -p /opt/liferay/connector-queue

	cron
}

function main {
	init

	register_crontab

	run_jobs
}

function register_crontab {
	if [ ! -e /mnt/liferay/connector-crontab ]
	then
		echo "The connector-crontab file is not available in the /mnt/liferay/ directory."

		exit 2
	fi

	(
		crontab -l 2>/dev/null
		cat /mnt/liferay/connector-crontab
	) | crontab -

	echo "The following crontab is installed:"
	cat /mnt/liferay/connector-crontab
	echo ""
}

function run_jobs {
	while true
	do
		if [ $(ls /opt/liferay/connector-queue | wc -l) -gt 0 ]
		then
			local connector_name=$(ls -tr /opt/liferay/connector-queue | head -n 1)

			rm "/opt/liferay/connector-queue/${connector_name}"

			connector_wrapper.sh "${connector_name}"
		else
			sleep 10
		fi
	done
}

main