#!/bin/bash

function add_lock {
	echo $(hostname) > /opt/liferay/shared-volume/liferay-startup-lock

	sleep 2

	if [ "$(hostname)" != "$(cat /opt/liferay/shared-volume/liferay-startup-lock)" ]
	then
		echo "Race condition was hit on locking, it's not ours, retrying."

		wait_until_free

		add_lock
	fi
}

function execute_background_task {
	nohup remove_lock_on_startup.sh &
}

function wait_until_free {
	while [ -e "/opt/liferay/shared-volume/liferay-startup-lock" ] && [ "$(hostname)" != "$(cat /opt/liferay/shared-volume/liferay-startup-lock)" ]
	do
		echo "Another Liferay node is in startup: $(cat /opt/liferay/shared-volume/liferay-startup-lock), waiting for it to finish. Remove the lock if it's there by mistake."

		sleep 3
	done

	echo "There's no startup lock in place, locking it for ourselves."
}

function main {
	wait_until_free

	add_lock

	execute_background_task
}

main