#!/bin/bash

function main {
	echo "[LIFERAY] To SSH into this container, run: \"docker exec -it ${HOSTNAME} /bin/bash\"."
	echo ""

	if [ ! -d /etc/liferay/mount ]
	then
		echo "[LIFERAY] Run this container with the option \"-v \$(pwd)/xyz123:/etc/liferay/mount\" to bridge \$(pwd)/xyz123 in the host operating system to /etc/liferay/mount on the container."
		echo ""
	fi

	if [ -d /etc/liferay/mount/files ]
	then
		if [ $(ls -A /etc/liferay/mount/files) ]
		then
			echo "[LIFERAY] Copying files from /etc/liferay/mount/files:"
			echo ""

			tree --noreport /etc/liferay/mount/files

			echo ""
			echo "[LIFERAY] ... into ${LIFERAY_HOME}."

			cp -r /etc/liferay/mount/files/* ${LIFERAY_HOME}

			echo ""
		fi
	else
		echo "[LIFERAY] The directory /etc/liferay/mount/files does not exist. Create the directory \$(pwd)/xyz123/files on the host operating system to create the directory /etc/liferay/mount/files on the container. Files in /etc/liferay/mount/files will be copied to ${LIFERAY_HOME} before ${LIFERAY_PRODUCT_NAME} starts."
		echo ""
	fi

	if [ -d /etc/liferay/mount/scripts ]
	then
		if [ $(ls -A /etc/liferay/mount/scripts) ]
		then
			echo "[LIFERAY] Executing scripts in /etc/liferay/mount/scripts:"

			for SCRIPT_NAME in /etc/liferay/mount/scripts/*
			do
				echo ""
				echo "[LIFERAY] Executing ${SCRIPT_NAME}."

				chmod a+x ${SCRIPT_NAME}

				${SCRIPT_NAME}
			done

			echo ""
		fi
	else
		echo "[LIFERAY] The directory /etc/liferay/mount/scripts does not exist. Create the directory \$(pwd)/xyz123/scripts on the host operating system to create the directory /etc/liferay/mount/scripts on the container. Files in /etc/liferay/mount/scripts will be executed, in alphabetical order, before ${LIFERAY_PRODUCT_NAME} starts."
		echo ""
	fi

	if [ -d /etc/liferay/mount/deploy ]
	then
		if [ $(ls -A /opt/liferay/deploy) ]
		then
			cp /opt/liferay/deploy/* /etc/liferay/mount/deploy
		fi

		rm -fr /opt/liferay/deploy

		ln -s /etc/liferay/mount/deploy /opt/liferay/deploy

		echo "[LIFERAY] The directory /etc/liferay/mount/deploy is ready. Copy files to \$(pwd)/xyz123/deploy on the host operating system to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
	else
		echo "[LIFERAY] The directory /etc/liferay/mount/deploy does not exist. Create the directory \$(pwd)/xyz123/deploy on the host operating system to create the directory /etc/liferay/mount/deploy on the container. Copy files to \$(pwd)/xyz123/deploy to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
	fi

	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	if [ "${LIFERAY_JPDA_ENABLED}" == "true" ]
	then
		${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
	else
		${LIFERAY_HOME}/tomcat/bin/catalina.sh run
	fi
}

main