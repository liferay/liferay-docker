#!/bin/bash

function check_usage {
	if [ "${ORCA_DEVELOPMENT_MODE}" == "true" ]
	then
		ORCA_VAULT_SERVICE_PASSWORD="development"
	fi

	if [ ! -n "${ORCA_VAULT_ADDRESSES}" ] || [ ! -n "${ORCA_VAULT_SERVICE_PASSWORD}" ]
	then
		echo "Set the environment variables ORCA_VAULT_ADDRESSES and ORCA_VAULT_SERVICE_PASSWORD."

		exit 1
	fi
}

function get_token {
	round=0

	while true
	do
		if [ "${round}" -le 120 ]
		then
			round=$((round+1))
		else
			echo "Fetching token for login ${1} was unsuccessful for 2 mins. Exiting"
			exit 1
		fi

		local token=$(curl --fail --request POST --silent "http://${ORCA_VAULT_ADDRESSES}/v1/auth/userpass-${1}/login/${1}" --data "{\"password\": \"${ORCA_VAULT_SERVICE_PASSWORD}\"}")
		if [ -n "${token}" ]
		then
			break
		fi
	done

	token=${token##*client_token\":\"}
	token=${token%%\"*}

	echo "${token}"
}

function load_secrets {
	mkdir -p /tmp/orca-secrets

	local token="${1}"
	shift

	for secret in "${@}"
	do
		local round=0

		while true;
		do
			if [ "${round}" -le 120 ]
				then
					echo "Fetching secret '${secret}'...round #$((round=round+1))."
				else
					echo "Fetching secret '${secret}' was unsuccessful for 2 mins. Exiting"
					exit 1
			fi

			local password=$(curl --fail --header "X-Vault-Token: ${token}" --request GET --silent "http://${ORCA_VAULT_ADDRESSES}/v1/secret/data/${secret}")

			ret="${?}"

			if [ "${ret}" -gt 0 ]
			then
				echo "Fetching secret '${secret}' failed with error ${ret}."
			fi

			if [ -n "${password}" ]
			then
				echo "Fetching secret '${secret}' succeeded."
				break
			fi
		done

		password=${password##*password\":\"}
		password=${password%%\"*}

		echo "${password}" > "/tmp/orca-secrets/${secret}"

		chmod 600 "/tmp/orca-secrets/${secret}"
	done
}

function main {
	local service="${1}"
	shift

	check_usage

	wait_for_vault

	load_secrets $(get_token "${service}") "${@}"

	unset ORCA_VAULT_TOKEN
}

function wait_for_vault {
	echo "Connecting to vault ${ORCA_VAULT_ADDRESSES}."

	while true
	do
		for ORCA_VAULT_ADDRESSES in ${ORCA_VAULT_ADDRESSES//,/ }
		do
			if ( curl --max-time 3 --silent "http://${ORCA_VAULT_ADDRESSES}/v1/sys/health" | grep "\"sealed\":false" &>/dev/null)
			then
				echo "Vault ${ORCA_VAULT_ADDRESSES} is available."

				return
			fi
		done

		echo "Waiting for at least one vault to become available."

		sleep 3
	done
}

main "${@}"