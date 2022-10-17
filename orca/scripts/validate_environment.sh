#!/bin/bash

function check_dir {
	local dir=${1}
	local uid=${2}

	if [ -d "${dir}" ]
	then
		if [ ! $(stat -c '%u' "${dir}") -eq "${uid}" ]
		then
			echo "The permissions of directory ${dir} are not correct. Change the owner to ${uid}."

			ORCA_VALIDATION_ERROR=1
		fi
	else
		echo "The directory ${dir} does not exist. Create it and change the owner to ${uid}."

		ORCA_VALIDATION_ERROR=1
	fi
}

function check_dirs {
	check_dir "/opt/liferay/db-data" 1001
	check_dir "/opt/liferay/jenkins-home" 1000
	check_dir "/opt/liferay/shared-volume/document-library" 1000
	check_dir "/opt/liferay/vault/data" 1000
}

function check_utils {
	for util in "${@}"
	do
		if (! command -v "${util}" &>/dev/null)
		then
			echo "The utility ${util} is not installed."

			ORCA_VALIDATION_ERROR=1
		fi
	done
}

function check_vm_max_map_count {
	local current_value=$(sysctl -n vm.max_map_count)

	if [ "${current_value}" -lt 262144 ]
	then
		echo "Elasticsearch requires vm.max_map_count to be at least 262144. Run \"sysctl -w vm.max_map_count=262144\" as a temporary solution or edit /etc/sysctl.conf and set vm.max_map_count to 262144 to make it permanent."

		ORCA_VALIDATION_ERROR=1
	fi
}

function main {
	check_utils docker docker-compose yq

	check_dirs

	check_vm_max_map_count

	if [ -n "${ORCA_VALIDATION_ERROR}" ]
	then
		echo "There was at least one error during validation. Please fix them before starting the services."

		exit 1
	fi
}

main