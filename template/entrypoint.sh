#!/bin/bash

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [ ! -d /liferay/docker ]
	then
		echo "[LIFERAY] Run this container with the option \"-v \${pwd}/xyz123:/liferay/docker\" to mount \${pwd}/xyz123 in the host operating system to /liferay/docker on the container."
		echo ""
	fi

	if [ -d /liferay/docker/home ]
	then
		echo "[LIFERAY] Copying files from /liferay/docker/home:"
		echo ""

		tree --noreport /liferay/docker/home

		echo ""
		echo "[LIFERAY] ... into /liferay/home."

		cp -r /liferay/docker/home /liferay/home
	else
		echo "[LIFERAY] The directory /liferay/docker/home does not exist. Files in /liferay/docker/home will be automatically copied to /liferay/home before ${LIFERAY_PRODUCT_NAME} starts."
	fi

	echo ""

	if [ -d /liferay/docker/scripts ]
	then
		echo "[LIFERAY] Executing scripts in /liferay/docker/scripts:"

		for SCRIPT_NAME in /liferay/docker/scripts/*
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_NAME}."
			echo ""

			chmod a+x ${SCRIPT_NAME}

			${SCRIPT_NAME}
		done
	else
		echo "[LIFERAY] The directory /liferay/docker/scripts does not exist. Files in /liferay/docker/scripts will be automatically executed, in alphabetical order, before ${LIFERAY_PRODUCT_NAME} starts."
	fi

	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	/liferay/home/tomcat/bin/catalina.sh run
}

main