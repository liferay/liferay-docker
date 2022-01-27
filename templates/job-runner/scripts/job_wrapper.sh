#!/bin/bash

function main {
	run_job "${1}"
}

function run_job {
	local job="${1}"

	echo ""
	echo "Starting to run job ${job}."
	echo ""

	time "/mnt/liferay/jobs/${1}.sh"
}

main "${@}"