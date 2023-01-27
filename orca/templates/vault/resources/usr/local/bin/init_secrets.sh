#!/bin/bash

source /usr/local/bin/_common.sh

function create_password {
	if (! vault kv get secret/data/${1} &>/dev/null)
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

	local password

	if [ "${ORCA_DEVELOPMENT_MODE}" == "true" ]
	then
		password="development"
	else
		password=$(pwgen -1 -s 20)
	fi

	vault write auth/userpass-${1}/users/${1} password="${password}" policies="${1}" >/dev/null

	local accessor_id=$(vault auth list -format=json | jq -r '.["userpass-backup/"].accessor')
	local entity_id=$(vault write -format=json identity/entity name="shared" policies="shared" | jq -r ".data.id")

	vault write identity/entity-alias name="${1}" canonical_id="${entity_id}" mount_accessor="${accessor_id}" >/dev/null

	echo ${password}
}

function init_operator {
	local operator_init=$(vault operator init -key-shares=1 -key-threshold=1)

	UNSEAL_KEY=$(echo "${operator_init}" | grep "Unseal Key 1:")
	UNSEAL_KEY=${UNSEAL_KEY##*: }

	VAULT_TOKEN=$(echo "${operator_init}" | grep "Initial Root Token:")
	VAULT_TOKEN=${VAULT_TOKEN##*: }

	vault operator unseal "${UNSEAL_KEY}" >/dev/null

	export VAULT_TOKEN

	wait_for_operator "\"standby\": false"

	vault secrets enable -path=secret kv
}

function main {
	wait_for_vault

	init_operator

	create_password mysql_backup_password
	create_password mysql_liferay_password
	create_password mysql_root_password

	SERVICES=("backup" "db" "liferay")

	declare -A service_passwords

	for service in "${SERVICES[@]}"
	do
		service_passwords[${service}]=$(create_service_password ${service})
	done

	create_policies

	save_secrets
}

function save_secrets {
	if [ "${ORCA_DEVELOPMENT_MODE}" == "true" ]
	then
		echo "${UNSEAL_KEY}" > /opt/liferay/vault/data/unseal_key
		echo "${VAULT_TOKEN}" > /opt/liferay/vault/data/root-token
	else
		echo "Distribute the serice passwords to the hosts which run them:"

		for service in "${SERVICES[@]}"
		do
			echo "echo \"${service_passwords[${service}]}\" > /opt/liferay/passwords/${service^^}"
		done

		echo ""
		echo "Please save the following secrets to 1Password:"
		echo "Root token: ${VAULT_TOKEN}"
		echo "Unseal key: ${UNSEAL_KEY}"
	fi
}

function wait_for_vault {
	while true
	do
		if (vault status | grep Initialized &>/dev/null)
		then
			echo "Vault server is available."

			break
		fi

		echo "Waiting for the vault server to become available."

		sleep 1
	done
}

main