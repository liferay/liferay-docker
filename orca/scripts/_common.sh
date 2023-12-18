#!/bin/bash

function check_utils {
	for util in "${@}"
	do
		if (! command -v "${util}" &>/dev/null)
		then
			echo "The utility ${util} is not installed."

			ORCA_VALIDATION_ERROR=1
		fi
	done
}

function docker_compose {
	if (command -v docker-compose &>/dev/null)
	then
		docker-compose "${@}"
	else
		docker compose "${@}"
	fi
}

function lcd {
	cd "${1}" || exit 3
}