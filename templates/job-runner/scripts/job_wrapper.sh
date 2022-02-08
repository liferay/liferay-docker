#!/bin/bash

function main {
	echo ""
	echo "Starting job ${1}."
	echo ""

	time /bin/bash "/mnt/liferay/jobs/${1}.sh"
}

main "${@}"