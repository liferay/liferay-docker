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

	configure_liferay.sh

	execute_scripts /usr/local/liferay/scripts/pre-startup

	start_liferay.sh

	execute_scripts /usr/local/liferay/scripts/post-shutdown
}

main