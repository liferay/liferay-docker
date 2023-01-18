#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [[ "${DOCKER_TCMALLOC_ENABLED}" == "true" ]]
	then
		LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4"
		echo -e '\nexport LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4"' >> ~/.bashrc

		export LD_PRELOAD
	fi

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

	start_liferay

	execute_scripts /usr/local/liferay/scripts/post-shutdown

}

function start_liferay {
	set +e

	start_liferay.sh &

	START_LIFERAY_PID=$!

	echo "${START_LIFERAY_PID}" > "${LIFERAY_PID}"

	wait ${START_LIFERAY_PID}
}

main