#!/bin/bash

function check_document_library_permissions {
	local dl_dir=/opt/shared-volume/document-library
	if [ -e ${dl_dir} ]
	then
		if ( ! ls -lnd ${dl_dir} | grep "1000 1000" &>/dev/null )
		then
			echo "The permissions of the ${dl_dir} are not correct. Please change the owner to 1000:1000."

			ERROR=1
		fi
	else
		echo "The document_library folder ${dl_dir} does not exist. Please create it and change the owner of it to uid:gid 1000:1000."

		ERROR=1
	fi
}

function check_utils {
	for util in docker-compose yq
	do
		command -v "${util}" >/dev/null 2>&1 || { echo >&2 "ERROR: The utility ${util} is not installed."; ERROR=1; }
	done
}

function check_vm_max_map_count {
	local current_value=$(sysctl -n vm.max_map_count)

	if [ ${current_value} -lt 262144 ]
	then
		echo "ERROR: Elasticsearch images require vm.max_map_count to be at least 262144. Run 'sysctl -w vm.max_map_count=262144' as a temporary solution or edit /etc/sysctl.conf and set vm.max_map_count to 262144 to make it permanent."

		ERROR=1
	fi
}

function main {
	check_document_library_permissions

	check_utils

	check_vm_max_map_count

	print_result
}

function print_result {
	if [ -n "${ERROR}" ]
	then
		echo "There was at least one error during validation. Please fix them before starting the services."

		exit 1
	fi
}

main