#!/bin/bash

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [ ! -d /opt/liferay/docker ]
	then
		echo "[LIFERAY] Run this container with the option \"-v \${pwd}/xyz123:/opt/liferay/docker\" to mount \${pwd}/xyz123 in the host operating system to /opt/liferay/docker on the container."
		echo ""
	fi

	if [ -d /opt/liferay/docker/home ]
	then
		echo "[LIFERAY] Copying files from /opt/liferay/docker/home:"
		echo ""

		tree --noreport /opt/liferay/docker/home

		echo ""
		echo "[LIFERAY] ... into /opt/liferay/home."

		cp -r /opt/liferay/docker/home /opt/liferay/home
	else
		echo "[LIFERAY] The directory /opt/liferay/docker/home does not exist. Files in /opt/liferay/docker/home will be automatically copied to /opt/liferay/home before ${LIFERAY_PRODUCT_NAME} starts."
	fi

	echo ""

	if [ -d /opt/liferay/docker/scripts ]
	then
		echo "[LIFERAY] Executing scripts in /opt/liferay/docker/scripts:"

		for SCRIPT_NAME in /opt/liferay/docker/scripts/*
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_NAME}."
			echo ""

			chmod a+x ${SCRIPT_NAME}

			${SCRIPT_NAME}
		done
	else
		echo "[LIFERAY] The directory /opt/liferay/docker/scripts does not exist. Files in /opt/liferay/docker/scripts will be automatically executed, in alphabetical order, before ${LIFERAY_PRODUCT_NAME} starts."
	fi

	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	/opt/liferay/home/tomcat/bin/catalina.sh run
}

main