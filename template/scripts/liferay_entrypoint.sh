#!/bin/bash

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [ -e /usr/local/bin/pre_configure.sh ]
	then
		/usr/local/bin/pre_configure.sh
	fi

	if [ -d /etc/liferay/mount ]
	then
		LIFERAY_MOUNT_DIR=/etc/liferay/mount
	else
		LIFERAY_MOUNT_DIR=/mnt/liferay
	fi

	export LIFERAY_MOUNT_DIR

	configure_liferay.sh

	if [ -e /usr/local/bin/pre_startup.sh ]
	then
		/usr/local/bin/pre_startup.sh
	fi

	start_liferay.sh

	if [ -e /usr/local/bin/post_shutdown.sh ]
	then
		/usr/local/bin/post_shutdown.sh
	fi
}

main