#!/bin/bash

function execute_scripts {
	if [ -e "${1}" ] && [[ $(ls -A "${1}") ]]
	then
		echo "[LIFERAY] Executing scripts in ${1}:"

		for SCRIPT_PATH in $(find "${1}" -maxdepth 1 -type f | sort)
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_PATH}."

			source "${SCRIPT_PATH}"
		done

		echo ""
	fi
}

