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
	if [[ "${LIFERAY_CONTAINER_STATUS_ENABLED}" == "true" ]]
	then
		echo "Container status: ${1}"
		(
			echo "status=${1}"
			echo "update_time=$(date +%s)"
		) > /opt/liferay/container_status
	fi
}