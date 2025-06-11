#!/bin/bash

function has_ssh_connection {
	ssh "root@${1}" "exit" &> /dev/null

	if [ "${?}" -eq 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}