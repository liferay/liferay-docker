#!/bin/bash

function check_usage {
	DELAY=5
	HEAP_DUMP_FOLDER="${LIFERAY_HOME}/data/heap_dumps"
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

				HEAP_DUMP_FOLDER=${1}

				;;
			-n)
				shift

				NUMBER_OF_HEAP_DUMPS=${1}

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
	local time=$(date +'%H%M%S')
	
	mkdir -p "${HEAP_DUMP_FOLDER}/${time}"

	echo "[Liferay] Generating ${HEAP_DUMP_FOLDER}/${time}/heapdump${id}.txt"

	jattach $(cat "${LIFERAY_PID}") dumpheap "${HEAP_DUMP_FOLDER}/${time}/heapdump${id}.txt"
}

main() {
	check_usage "${@}"

	if [ ! -e "${HEAP_DUMP_FOLDER}" ]
	then
		mkdir -p "${HEAP_DUMP_FOLDER}"
	fi

	for i in $(seq 1 $NUMBER_OF_HEAP_DUMPS)
	do
		generate_heap_dump $i
		sleep $DELAY
	done

	echo "[Liferay] Heap dumps generated"
}

function print_help {
	echo "Usage: ${0} -t <HEAP_DUMP_FOLDER>"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Delay in seconds between two heap dump generation."
	echo "	-f (optional): Folder path to which the heap dumps are saved."
	echo "	-n (optional): Number of heap dumps to generate."
	echo ""
	echo "Example: ${0} -d 10 -n 30 -t \"${LIFERAY_HOME}/my_heap_dumps_folder\""

	exit 2
}

main "${@}"