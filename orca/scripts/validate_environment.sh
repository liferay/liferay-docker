#!/bin/bash

source $(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh

function create_dir {
	local dir="${1}"
	local service_uid="${2}"

	if [ -d "${dir}" ]
	then
		if [ ! "$(stat -c '%u' "${dir}")" -eq "${service_uid}" ]
		then
			echo -n "Setting owner of ${dir} to ${service_uid}... "

			if (sudo chown "${service_uid}" "${dir}")
			then
				echo "done."
			else
				echo "failed."

				ORCA_VALIDATION_ERROR=1
			fi
		fi
	else
		echo -n "${dir} does not exist, creating... "

		if (sudo install -d "${dir}" -o "${service_uid}")
		then
			echo "done."
		else
			echo "failed."

			ORCA_VALIDATION_ERROR=1
		fi
	fi
}

function create_dirs {
	local db_uid=1001
	local default_uid=1000

	if [ "${DOCKER_HOST}" == "unix:///run/user/$(id -u)/docker.sock" ]
	then
		db_uid=1000
		default_uid=166535
	fi

	create_dir "/opt/liferay/backups" ${default_uid}
	create_dir "/opt/liferay/db-data" ${db_uid}
	create_dir "/opt/liferay/jenkins-home" ${default_uid}
	create_dir "/opt/liferay/monitoring-proxy-db-data" ${db_uid}
	create_dir "/opt/liferay/shared-volume" ${default_uid}
	create_dir "/opt/liferay/shared-volume/document-library" ${default_uid}
	create_dir "/opt/liferay/vault/data" ${default_uid}
}

function main {
	check_utils docker yq

	create_dirs

	set_vm_max_map_count

	if [ -n "${ORCA_VALIDATION_ERROR}" ]
	then
		echo "There was at least one error during validation. Please fix them before starting the services."

		exit 1
	fi
}

function set_vm_max_map_count {
	echo "Setting sysctl value: \"vm.max_map_count=262144\"... "

	if (sudo sysctl -w vm.max_map_count=262144)
	then
		echo "done."
	else
		echo "failed."

		ORCA_VALIDATION_ERROR=1
	fi
}

main