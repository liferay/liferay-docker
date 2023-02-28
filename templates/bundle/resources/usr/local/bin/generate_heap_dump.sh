#!/bin/bash

function check_usage {
	HEAP_DUMPS_DIR="${LIFERAY_HOME}/data/sre/heap_dumps"

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				HEAP_DUMPS_DIR=${1}

				;;
			-h)
				print_help

				;;
			*)
				print_help

				;;
		esac

		shift
	done
}

function generate_heap_dump {
	local date=$(date +'%Y-%m-%d')

	mkdir -p "${HEAP_DUMPS_DIR}/${date}"

	local time=$(date +'%H-%M-%S')

	echo "[Liferay] Generating ${HEAP_DUMPS_DIR}/${date}/heap_dump-${time}.txt"

	jattach $(cat "${LIFERAY_PID}") dumpheap "${HEAP_DUMPS_DIR}/${date}/heap_dump-${time}.txt"
}

function main {
	check_usage "${@}"

	mkdir -p "${HEAP_DUMPS_DIR}"

	generate_heap_dump

	echo "[Liferay] Generated heap dump"
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Directory path to which heap dumps are saved"
	echo ""
	echo "Example: ${0} -d \"${HEAP_DUMPS_DIR}\""

	exit 2
}

main "${@}"