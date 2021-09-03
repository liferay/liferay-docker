#!/bin/bash

function configure_lefthook {
	local script_path="$( cd -- "$(dirname "$0")" || exit 1 >/dev/null 2>&1 ; pwd -P )"
	cd "${script_path//validation/}" || exit 1
	lefthook add pre-commit
}

function install_lefthook {
	apt-get update
	apt-get -y install npm
	npm install @arkweid/lefthook --save-dev
}

function install_shellcheck {
	docker pull koalaman/shellcheck:v0.7.2
}

function main {
	install_lefthook
	install_shellcheck
	configure_lefthook
}

main