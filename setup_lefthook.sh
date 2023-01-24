#!/bin/bash

function check_permission {
	if [ "$(id -u)" -ne 0 ]
	then
		echo "This script must be run by root."

		exit 1
	fi
}

function configure_lefthook {
	cd "$(dirname "$0")" || exit

	npx lefthook add pre-commit

	if [ "${exit_code}" -gt 0 ]
	then
		echo "Unable to configure Lefthook."

		exit 1
	fi
}

function install_lefthook {
	npm install @arkweid/lefthook@0.7.7 --save-dev

	local exit_code=$?

	if [ "${exit_code}" -gt 0 ]
	then
		echo "Unable to install Lefthook."

		exit 1
	fi
}

function install_npm {
	apt install npm

	local exit_code=$?

	if [ "${exit_code}" -gt 0 ]
	then
		echo "Unable to install NPM."

		exit 1
	fi
}

function main {
	check_permission

	install_npm

	install_lefthook

	configure_lefthook
}

main "${@}"
