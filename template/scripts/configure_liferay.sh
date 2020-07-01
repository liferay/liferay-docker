#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function main {
	if [ "${LIFERAY_DISABLE_TRIAL_LICENSE}" == "true" ]
	then
		rm -f /opt/liferay/deploy/trial-license-*.xml
	fi

	if [ ! -d ${LIFERAY_MOUNT_DIR} ]
	then
		echo "[LIFERAY] Run this container with the option \"-v \$(pwd)/xyz123:/mnt/liferay\" to bridge \$(pwd)/xyz123 in the host operating system to ${LIFERAY_MOUNT_DIR} on the container."
		echo ""
	fi

	if [ -d ${LIFERAY_MOUNT_DIR}/files ]
	then
		if [[ $(ls -A ${LIFERAY_MOUNT_DIR}/files) ]]
		then
			echo "[LIFERAY] Copying files from ${LIFERAY_MOUNT_DIR}/files:"
			echo ""

			tree --noreport ${LIFERAY_MOUNT_DIR}/files

			echo ""
			echo "[LIFERAY] ... into ${LIFERAY_HOME}."

			cp -r ${LIFERAY_MOUNT_DIR}/files/* ${LIFERAY_HOME}

			echo ""
		fi
	else
		echo "[LIFERAY] The directory /mnt/liferay/files does not exist. Create the directory \$(pwd)/xyz123/files on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/files on the container. Files in ${LIFERAY_MOUNT_DIR}/files will be copied to ${LIFERAY_HOME} before ${LIFERAY_PRODUCT_NAME} starts."
		echo ""
	fi

	if [ -d ${LIFERAY_MOUNT_DIR}/scripts ]
	then
		execute_scripts ${LIFERAY_MOUNT_DIR}/scripts
	else
		echo "[LIFERAY] The directory /mnt/liferay/scripts does not exist. Create the directory \$(pwd)/xyz123/scripts on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/scripts on the container. Files in ${LIFERAY_MOUNT_DIR}/scripts will be executed, in alphabetical order, before ${LIFERAY_PRODUCT_NAME} starts."
		echo ""
	fi

	if [ -d ${LIFERAY_MOUNT_DIR}/deploy ]
	then
		if [[ $(ls -A /opt/liferay/deploy) ]]
		then
			cp /opt/liferay/deploy/* ${LIFERAY_MOUNT_DIR}/deploy
		fi

		rm -fr /opt/liferay/deploy

		ln -s ${LIFERAY_MOUNT_DIR}/deploy /opt/liferay/deploy

		echo "[LIFERAY] The directory /mnt/liferay/deploy is ready. Copy files to \$(pwd)/xyz123/deploy on the host operating system to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
	else
		echo "[LIFERAY] The directory /mnt/liferay/deploy does not exist. Create the directory \$(pwd)/xyz123/deploy on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/deploy on the container. Copy files to \$(pwd)/xyz123/deploy to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
	fi

	export LIFERAY_PATCHING_DIR=${LIFERAY_MOUNT_DIR}/patching

	if [ -e ${LIFERAY_PATCHING_DIR} ] && [ -e /opt/liferay/patching-tool ]
	then
		patch_liferay.sh
	fi
}

main