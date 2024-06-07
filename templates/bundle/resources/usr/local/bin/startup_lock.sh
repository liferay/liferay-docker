#!/bin/bash

function add_lock {
	echo "Acquiring lock."

	hostname > "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}"

	sleep 2

	if [ "$(hostname)" != "$(cat "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}")" ]
	then
		echo "Unable to acquire lock."

		wait_until_free

		add_lock
	else
		echo "Lock acquired by $(hostname)."
	fi
}

function wait_until_free {
	while
		[ -e "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ] &&
		[ -n "$(cat "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}")" ] &&
		[ "$(hostname)" != "$(cat "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}")" ]
	do
		echo "Wait for $(cat "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}") to start up."

		if [ "$(find "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" -mmin +2)" ]
		then
			echo "Lock created by $(cat "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}") was not updated for 2 minutes, unlocking."

			echo "" > "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}"

			break
		fi

		sleep 3
	done
}

function main {
	local delay=$((RANDOM % 10 + 1))

	echo "Delaying lock check for ${delay} seconds."

	sleep ${delay}

	wait_until_free

	add_lock
}

main