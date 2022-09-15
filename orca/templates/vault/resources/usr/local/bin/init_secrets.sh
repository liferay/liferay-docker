#!/bin/bash

function check_usage {
	if [ ! -n "$VAULT_TOKEN" ]
	then
		echo "Set VAULT_TOKEN environment before running this script."
	fi
}

function create_password {
	if ( ! secret_exists ${1} )
	then
		local password=$(pwgen -1 -s 20)
		echo "{\"data\": {\"password\": \"${password}\"}}" | curl_vault POST v1/secret/data/${1}
	else
		echo "Secret ${1} already exists, skippping."
	fi
}

function secret_exists {
	echo "" | curl_vault GET v1/secret/data/${1} > /dev/null 2>&1

	return ${?}
}

function curl_vault {
	local request=${1}
	local path=${2}

	curl --data @- --header "X-Vault-Token: $VAULT_TOKEN" --request ${request} --silent http://127.0.0.1:8200/${path}
}

function main {
	check_usage

	create_password mysql_backup_password
	create_password mysql_liferay_password
	create_password mysql_root_password
}

main