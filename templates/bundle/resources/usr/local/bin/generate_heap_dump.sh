#!/bin/bash

function check_usage {
	HEAP_DUMP_DIR="${LIFERAY_HOME}/data/sre/heap_dumps"

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				HEAP_DUMP_DIR=${1}

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

generate_heap_dump() {
	local date=$(date +'%Y-%m-%d')
	local time=$(date +'%H-%M-%S')
	
	mkdir -p "${HEAP_DUMP_DIR}/${date}"

	echo "[Liferay] Generating ${HEAP_DUMP_DIR}/${date}/heap_dump-${time}.txt"

	jattach $(cat "${LIFERAY_PID}") dumpheap "${HEAP_DUMP_DIR}/${date}/heap_dump-${time}.txt"
}

main() {
	check_usage "${@}"

	mkdir -p "${HEAP_DUMP_DIR}"

	generate_heap_dump

	echo "[Liferay] Heap dump generated"
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Directory path to which the heap dumps are saved."
	echo ""
	echo "Example: ${0} -d \"${HEAP_DUMP_DIR}\""

	exit 2
}

main "${@}"