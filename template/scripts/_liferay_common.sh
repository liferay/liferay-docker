#!/bin/bash

function execute_scripts_folder {
	if [ -e ${1} ] && [[ $(ls -A ${1}) ]]
	then
		echo "[LIFERAY] Executing scripts in ${1}:"

		for SCRIPT_NAME in ${1}/*
		do
			echo ""
			echo "[LIFERAY] Executing ${SCRIPT_NAME}."

			if [ ! -x ${SCRIPT_NAME} ]
			then
				chmod a+x ${SCRIPT_NAME}
			fi

			${SCRIPT_NAME}
		done

		echo ""
	fi
}