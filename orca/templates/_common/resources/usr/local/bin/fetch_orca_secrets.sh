#!/bin/bash

function check_usage {
	if [ ! -n "${ORCA_VAULT_ADDRESSES}" ] ||  [ ! -n "${ORCA_VAULT_TOKEN}" ]
	then
		echo "Set the environment variables ORCA_VAULT_ADDRESSES and ORCA_VAULT_TOKEN."

		exit 1
	fi
}

function load_secrets {
	mkdir -p /tmp/orca-secrets

	for secret in "${@}"
	do
       local password=$(curl --fail --header "X-Vault-Token: ${ORCA_VAULT_TOKEN}" --request GET --silent "http://${VAULT_ADDRESS}/v1/secret/data/${secret}")
       password=${password##*password\":\"}
       password=${password%%\"*}

       echo "${password}" > "/tmp/orca-secrets/${secret}"
       
       chmod 600 "/tmp/orca-secrets/${secret}"
	done
}

function main {
	check_usage

	wait_for_vault

	load_secrets "${@}"

	unset ORCA_VAULT_TOKEN
}

function wait_for_vault {
	echo "Connecting to vault: ${ORCA_VAULT_ADDRESSES}."

	while true
	do
		for vault_address in ${ORCA_VAULT_ADDRESSES//,/ }
		do
			if ( curl --max-time 3 --silent "http://${vault_address}/v1/sys/health" | grep "\"sealed\":false" &>/dev/null)
			then
				echo "Vault server ${vault_address} is available."

				VAULT_ADDRESS=${vault_address}

				return
			fi
		done

		echo "Waiting for at least one vault server to become available."

		sleep 3
	done
}

main "${@}"