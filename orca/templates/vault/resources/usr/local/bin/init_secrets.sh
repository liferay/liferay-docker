#!/bin/bash

function check_usage {
	if [ ! -n "${ORCA_VAULT_TOKEN}" ]
	then
		echo "Set the environment variable ORCA_VAULT_TOKEN."

		exit 1
	fi
}

function create_password {
	if ( ! has_secret ${1} )
	then
		local password=$(pwgen -1 -s 20)

		echo "{\"data\": {\"password\": \"${password}\"}}" | curl_vault POST "v1/secret/data/${1}" > /dev/null

		echo "Generated secret ${1}."
	else
		echo "Secret ${1} already exists."
	fi
}

function curl_vault {
	curl --data @- --fail --header "X-Vault-Token: ${ORCA_VAULT_TOKEN}" --request ${1} --silent http://127.0.0.1:8200/${2}

	return ${?}
}

function has_secret {
	echo "" | curl_vault GET v1/secret/data/${1} > /dev/null 2>&1

	return ${?}
}

function main {
	check_usage

	create_password mysql_backup_password
	create_password mysql_liferay_password
	create_password mysql_root_password
}

main