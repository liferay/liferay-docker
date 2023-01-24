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

function create_policies {
	for policy in policy_*.hcl
	do
		local policy_name=${policy#"policy_"}

		policy_name=${policy_name%".hcl"}

		vault policy write ${policy_name} ${policy}
	done
}

function create_service_password {
	vault auth enable -path="userpass-${1}" userpass >/dev/null

	local password=$(pwgen -1 -s 20)

	vault write auth/userpass-${1}/users/${1} password="${password}" policies="${1}" >/dev/null

	local accessor_id=$(vault auth list -format=json | jq -r '.["userpass-backup/"].accessor')
	local entity_id=$(vault write -format=json identity/entity name="shared" policies="shared" | jq -r ".data.id")

	vault write identity/entity-alias name="${1}" canonical_id="${entity_id}" mount_accessor="${accessor_id}" >/dev/null

	echo ${password}
}

function main {
	check_usage

	vault secrets enable -path=secret kv >/dev/null 2>&1

	create_password mysql_backup_password
	create_password mysql_liferay_password
	create_password mysql_root_password

	create_policies

	echo "echo \"$(create_service_password backup)\" > /opt/liferay/passwords/BACKUP"
	echo "echo \"$(create_service_password db)\" > /opt/liferay/passwords/DB"
	echo "echo \"$(create_service_password liferay)\" > /opt/liferay/passwords/LIFERAY"
}

main
