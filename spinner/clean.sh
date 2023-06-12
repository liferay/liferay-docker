#!/bin/bash

source ../_liferay_common.sh

function clean_up {
	echo "Cleaning up ${1}."

	lc_cd "${1}"

	$(lc_docker_compose) down --rmi local --volumes

	rm -fr "${1}"
}

function main {
	if [[ $(find . -name "env-*" -type d | wc -l) -eq 0 ]]
	then
		echo "There are no stack directories to clean."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	LIFERAY_COMMON_LOG_DIR="/tmp/spinner-clean.${$}"

	for stack_dir in "$(pwd)"/env-*
	do
		lc_time_run clean_up "${stack_dir}"
	done
}

main