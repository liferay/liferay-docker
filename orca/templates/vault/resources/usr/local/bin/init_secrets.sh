#!/bin/bash

function check_usage {
	if [ ! -n "${ORCA_VAULT_TOKEN}" ]
	then
		echo "Set the environment variable ORCA_VAULT_TOKEN."

		exit 1
	fi

	export VAULT_TOKEN="${ORCA_VAULT_TOKEN}"
}

function create_password {
	if ( ! vault kv get secret/data/${1} > /dev/null 2>&1 )
	then
		local password=$(pwgen -1 -s 20)

		vault kv put secret/data/${1} "password=${password}"

		echo "Generated secret ${1}."
	else
		echo "Secret ${1} already exists."
	fi
}

function main {
	check_usage

	vault secrets enable -path=secret kv >/dev/null 2>&1

	create_password mysql_backup_password
	create_password mysql_liferay_password
	create_password mysql_root_password
}

main