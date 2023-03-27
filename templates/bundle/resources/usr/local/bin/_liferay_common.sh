#!/bin/bash

function execute_scripts {
	if [ -e "${1}" ] && [[ $(find "${1}" -maxdepth 1 -name "*.sh" -printf "%f\n") ]]
	then
		echo "[LIFERAY] Executing scripts in ${1}:"

		for SCRIPT_NAME in $(find "${1}" -maxdepth 1 -name "*.sh" -printf "%f\n" | sort)
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_NAME}."

			source "${1}/${SCRIPT_NAME}"
		done

		echo ""
	fi
}

function update_container_status {
	if [[ "${LIFERAY_CONTAINER_STATUS_ENABLED}" != "true" ]]
	then
		return
	fi

	local old_status=$(grep status= /opt/liferay/container_status)
	old_status=${old_status#status=}

	if [ "${old_status}" == "${1}" ]
	then
		touch /opt/liferay/container_status

		return
	fi

	echo "Container status: ${1}"

	(
		echo "status=${1}"
		echo "update_time=$(date +%s)"
	) > /opt/liferay/container_status

}