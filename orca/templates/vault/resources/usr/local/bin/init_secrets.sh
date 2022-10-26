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
	vault policy write shared shared.hcl
	vault policy write backup backup.hcl
	vault policy write db db.hcl
	vault policy write liferay liferay.hcl
}

function create_services_auth {
	vault auth enable -path="userpass-${1}" userpass

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

	create_policies

	local backup_password=$(create_services_auth backup)
	local db_password=$(create_services_auth db)
	local liferay_password=$(create_services_auth liferay)

	create_password mysql_backup_password
	create_password mysql_liferay_password
	create_password mysql_root_password

	echo "echo \"${backup_password}\" > /opt/liferay/passwords/BACKUP"
	echo "echo \"${db_password}\" > /opt/liferay/passwords/DB"
	echo "echo \"${liferay_password}\" > /opt/liferay/passwords/LIFERAY"
}

main