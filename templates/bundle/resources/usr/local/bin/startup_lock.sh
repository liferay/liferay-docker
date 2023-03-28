#!/bin/bash

function add_lock {
	hostname > /opt/liferay/data/liferay-startup-lock

	sleep 2

	if [ "$(hostname)" != "$(cat /opt/liferay/data/liferay-startup-lock)" ]
	then
		echo "Unable to acquire lock."

		wait_until_free

		add_lock
	fi
}

function wait_until_free {
	while [ -e "/opt/liferay/data/liferay-startup-lock" ] && [ "$(hostname)" != "$(cat /opt/liferay/data/liferay-startup-lock)" ]
	do
		echo "Wait for $(cat /opt/liferay/data/liferay-startup-lock) to start up."

		sleep 3
	done

	echo "Acquiring lock."
}

function main {
	wait_until_free

	add_lock

	nohup remove_lock_on_startup.sh &
}

main