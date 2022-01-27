#!/bin/bash

function main {
	run_connector "${1}"
}

function run_connector {
	local connector="${1}"

	echo ""
	echo "Starting to run connector ${connector}."
	echo ""

	time "/mnt/liferay/connectors/${1}.sh"
}

main "${@}"