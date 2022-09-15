#!/bin/bash

set -e

function get_secret {
	curl --fail --header "X-Vault-Token: $VAULT_TOKEN" --request GET --silent http://127.0.0.1:8200/v1/secret/data/${1} | jq .data.data.password | sed -e s/\"//g
}

function main {
	for secret in $(cat secrets | sed -e s/.*:// | sort | uniq)
	do
		echo ${secret}
		password=$(get_secret ${secret})
		echo ${password}
	done
}

main