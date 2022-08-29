#!/bin/bash

function check_dir {
	local dir=${1}
	local uid=${2}

	if [ -d "${dir}" ]
	then
		if [ ! $(stat -c '%u' "${dir}") -eq "${uid}" ]
		then
			echo "The permissions of the ${dir} are not correct. Please change the owner to uid ${uid}."

			ERROR=1
		fi
	else
		echo "The directory ${dir} does not exist. Please create it and change the owner of it to uid ${uid}."

		ERROR=1
	fi
}

function check_dirs {
	check_dir "/opt/liferay/db-data" 1001
	check_dir "/opt/liferay/jenkins-home" 1000
	check_dir "/opt/liferay/shared-volume/document-library" 1000
	check_dir "/opt/liferay/vault/data/" 1000
}

function check_utils {
	for util in docker-compose yq
	do
		command -v "${util}" >/dev/null 2>&1 || { echo >&2 "ERROR: The utility ${util} is not installed."; ERROR=1; }
	done
}

function check_vm_max_map_count {
	local current_value=$(sysctl -n vm.max_map_count)

	if [ "${current_value}" -lt 262144 ]
	then
		echo "ERROR: Elasticsearch images require vm.max_map_count to be at least 262144. Run 'sysctl -w vm.max_map_count=262144' as a temporary solution or edit /etc/sysctl.conf and set vm.max_map_count to 262144 to make it permanent."

		ERROR=1
	fi
}

function main {
	check_utils

	check_dirs

	check_vm_max_map_count

	if [ -n "${ERROR}" ]
	then
		echo "There was at least one error during validation. Please fix them before starting the services."

		exit 1
	fi
}

main