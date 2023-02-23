#!/bin/bash

function check_usage {
	DELAY=5
	HEAP_DUMP_DIRECTORY="${LIFERAY_HOME}/data/heap_dumps"
	NUMBER_OF_HEAP_DUMPS=20

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				DELAY=${1}

				;;
			-f)
				shift

				HEAP_DUMP_DIRECTORY=${1}

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
	local id=$2
	local date=$(date +'%D-%H:%M:%S')
	
	mkdir -p "${HEAP_DUMP_DIRECTORY}/${date}"

	echo "[Liferay] Generating ${HEAP_DUMP_DIRECTORY}/${date}/heapdump${id}.txt"

	jattach $(cat "${LIFERAY_PID}") dumpheap "${HEAP_DUMP_DIRECTORY}/${date}/heapdump${id}.txt"
}

main() {
	check_usage "${@}"

	mkdir -p "${HEAP_DUMP_DIRECTORY}"

	for i in $(seq 1 $NUMBER_OF_HEAP_DUMPS)
	do
		generate_heap_dump $i
		sleep $DELAY
	done

	echo "[Liferay] Heap dumps generated"
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Delay in seconds between two heap dump generation."
	echo "	-f (optional): Directory path to which the heap dumps are saved."
	echo ""
	echo "Example: ${0} -d $DELAY -f \"${HEAP_DUMP_DIRECTORY}\""

	exit 2
}

main "${@}"