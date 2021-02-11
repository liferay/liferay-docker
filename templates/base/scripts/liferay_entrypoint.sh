#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [ -d /etc/liferay/mount ]
	then
		LIFERAY_MOUNT_DIR=/etc/liferay/mount
	else
		LIFERAY_MOUNT_DIR=/mnt/liferay
	fi

	export LIFERAY_MOUNT_DIR

	execute_scripts /usr/local/liferay/scripts/pre-configure

	. set_java_version.sh

	. configure_liferay.sh

	execute_scripts /usr/local/liferay/scripts/pre-startup

	trap 'handle_termination' TERM INT

	start_liferay.sh &

	wait_termination

	exit_code=$?

	execute_scripts /usr/local/liferay/scripts/post-shutdown

	exit $exit_code
}

function handle_termination {
	if [ $liferay_pid ]
	then
		kill -TERM $liferay_pid
	else
		term_kill_needed="yes"
	fi
}

function wait_termination {
	liferay_pid=$!

	if [ $term_kill_needed ]
	then
		kill -TERM $liferay_pid
	fi

	wait $liferay_pid

	trap - TERM INT

	wait $liferay_pid
}

main