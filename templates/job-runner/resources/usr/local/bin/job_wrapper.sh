#!/bin/bash

function main {
	echo ""
	echo "Running job ${1}."
	echo ""

	time /bin/bash "/mnt/liferay/jobs/${1}.sh"
}

main "${@}"
