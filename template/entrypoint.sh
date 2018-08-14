#!/bin/bash

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [ ! -d /etc/liferay/mount ]
	then
		echo "[LIFERAY] Run this container with the option \"-v \${pwd}/xyz123:/etc/liferay/mount\" to bridge \${pwd}/xyz123 in the host operating system to /etc/liferay/mount on the container."
		echo ""
	fi

	if [ -d /etc/liferay/mount/files ]
	then
		echo "[LIFERAY] Copying files from /etc/liferay/mount/files:"
		echo ""

		tree --noreport /etc/liferay/mount/files

		echo ""
		echo "[LIFERAY] ... into ${LIFERAY_HOME}."

		cp -r /etc/liferay/mount/files ${LIFERAY_HOME}
	else
		echo "[LIFERAY] The directory /etc/liferay/mount/files does not exist. Files in /etc/liferay/mount/files will be automatically copied to ${LIFERAY_HOME} before ${LIFERAY_PRODUCT_NAME} starts."
	fi

	echo ""

	if [ -d /etc/liferay/mount/scripts ]
	then
		echo "[LIFERAY] Executing scripts in /etc/liferay/mount/scripts:"

		for SCRIPT_NAME in /etc/liferay/mount/scripts/*
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_NAME}."
			echo ""

			chmod a+x ${SCRIPT_NAME}

			${SCRIPT_NAME}
		done
	else
		echo "[LIFERAY] The directory /etc/liferay/mount/scripts does not exist. Files in /etc/liferay/mount/scripts will be automatically executed, in alphabetical order, before ${LIFERAY_PRODUCT_NAME} starts."
	fi

	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	${LIFERAY_HOME}/tomcat/bin/catalina.sh run
}

main