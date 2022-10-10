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
		echo "Fetching secret ${secret}."

		local password=$(curl --fail --header "X-Vault-Token: ${ORCA_VAULT_TOKEN}" --request GET --silent "http://${ORCA_VAULT_ADDRESSES}/v1/secret/data/${secret}")

		if [ "${?}" -gt 0 ]
		then
			echo "Fetching secret failed with error ${?}"
		fi

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
		for ORCA_VAULT_ADDRESSES in ${ORCA_VAULT_ADDRESSES//,/ }
		do
			if ( curl --max-time 3 --silent "http://${ORCA_VAULT_ADDRESSES}/v1/sys/health" | grep "\"sealed\":false" &>/dev/null)
			then
				echo "Vault server ${ORCA_VAULT_ADDRESSES} is available."

				return
			fi
		done

		echo "Waiting for at least one vault server to become available."

		sleep 3
	done
}

main "${@}"