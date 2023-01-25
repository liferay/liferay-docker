#!/bin/bash

function create_dir {
	local dir="${1}"
	local service_uid="${2}"

	if [ -d "${dir}" ]
	then
		if [ ! $(stat -c '%u' "${dir}") -eq "${service_uid}" ]
		then
			echo -n "Setting owner of ${dir} to ${service_uid}..."
			if ( sudo chown "${service_uid}" "${dir}" )
			then
				echo "done."
			else
				echo "failed!"
				ORCA_VALIDATION_ERROR=1
			fi
		fi
	else
		echo -n "${dir} does not exist, creating..."
		if ( sudo install -d "${dir}" -o "${service_uid}" )
		then
			echo "done."
		else
			echo "failed!"
		        ORCA_VALIDATION_ERROR=1
		fi
	fi
}

function create_dirs {
	create_dir "/opt/liferay/db-data" 1001
	create_dir "/opt/liferay/jenkins-home" 1000
	create_dir "/opt/liferay/monitoring-proxy-db-data" 1001
	create_dir "/opt/liferay/shared-volume/document-library" 1000
	create_dir "/opt/liferay/vault/data" 1000
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

	create_dirs

	check_vm_max_map_count

	if [ -n "${ORCA_VALIDATION_ERROR}" ]
	then
		echo "There was at least one error during validation. Please fix them before starting the services."

		exit 1
	fi
}

main