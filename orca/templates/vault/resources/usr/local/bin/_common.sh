#!/bin/bash

function wait_for_operator {
	while true
	do
		if ( curl --max-time 3 --silent "http://localhost:8200/v1/sys/health" | grep "${1}" &>/dev/null)
		then
			echo "Vault operator is available."

			break
		fi

		echo "Waiting for the operator to become available."

		sleep 1
	done
}