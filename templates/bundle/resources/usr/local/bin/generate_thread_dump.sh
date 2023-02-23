#!/bin/bash

function check_usage {
	DELAY=5
	NUMBER_OF_THREAD_DUMPS=20
	THREAD_DUMP_DIRECTORY="${LIFERAY_HOME}/data/thread_dumps"

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				DELAY=${1}

				;;
			-f)
				shift

				THREAD_DUMP_DIRECTORY=${1}

				;;
			-n)
				shift

				NUMBER_OF_THREAD_DUMPS=${1}

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

generate_thread_dump() {
	local id=$2
	local date=$(date +'%D-%H:%M:%S')
	
	mkdir -p "${THREAD_DUMP_DIRECTORY}/${date}"

	echo "[Liferay] Generating ${THREAD_DUMP_DIRECTORY}/${date}/threaddump${id}.txt"

	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)
	 echo -e "${thread_dump}" > "${THREAD_DUMP_DIRECTORY}/${date}/threaddump${id}.txt"
}

main() {
	check_usage "${@}"

	mkdir -p "${THREAD_DUMP_DIRECTORY}"

	for i in $(seq 1 $NUMBER_OF_THREAD_DUMPS)
	do
		generate_thread_dump $i
		sleep $DELAY
	done

	echo "[Liferay] Thread dumps generated"
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Delay in seconds between two thread dump generation."
	echo "	-f (optional): Directory path to which the thread dumps are saved."
	echo "	-n (optional): Number of thread dumps to generate."
	echo ""
	echo "Example: ${0} -d $DELAY -n $NUMBER_OF_THREAD_DUMPS -f \"${THREAD_DUMP_DIRECTORY}\""

	exit 2
}

main "${@}"