#!/bin/bash

source ../_liferay_common.sh

function main {
	if [[ $(find . -name "env-*" -type d | wc -l) -eq 0 ]]
	then
		echo "There are no environments to clean."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	for lxc_environment in "$(pwd)"/env-*
	do
		echo "Cleaning up ${lxc_environment}."

		lcd "${lxc_environment}"

		$(lc_docker_compose) down --rmi local -v

		rm -fr "${lxc_environment}"
	done
}

main