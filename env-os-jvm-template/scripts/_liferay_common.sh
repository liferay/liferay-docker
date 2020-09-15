#!/bin/bash

function execute_scripts {
	if [ -e ${1} ] && [[ $(ls -A ${1}) ]]
	then
		echo "[LIFERAY] Executing scripts in ${1}:"

		for SCRIPT_NAME in $(ls -1 ${1} | sort)
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_NAME}."

			source ${1}/${SCRIPT_NAME}
		done

		echo ""
	fi
}