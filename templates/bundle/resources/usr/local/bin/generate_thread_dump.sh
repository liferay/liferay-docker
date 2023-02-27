#!/bin/bash

function check_usage {
	SLEEP=5
	NUMBER_OF_THREAD_DUMPS=20
	THREAD_DUMP_DIR="${LIFERAY_HOME}/data/sre/thread_dumps"

	while [ "${1}" != "" ]
	do
		case ${1} in

			-d)
				shift

				THREAD_DUMP_DIR=${1}

				;;
			-n)
				shift

				NUMBER_OF_THREAD_DUMPS=${1}

				;;
			-s)
				shift

				SLEEP=${1}

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
	local id=${2}
	local date=$(date +'%Y-%m-%d')
	local time=$(date +'%H-%M-%S')
	
	mkdir -p "${THREAD_DUMP_DIR}/${date}"

	echo "[Liferay] Generating ${THREAD_DUMP_DIR}/${date}/thread_dump-${time}-${id}.txt"

	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)
	echo -e "${thread_dump}" > "${THREAD_DUMP_DIR}/${date}/thread_dump-${time}-${id}.txt"
}

main() {
	check_usage "${@}"

	for i in $(seq 1 ${NUMBER_OF_THREAD_DUMPS})
	do
		generate_thread_dump ${i}

		sleep ${SLEEP}
	done

	echo "[Liferay] Thread dumps generated"
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Directory path to which the thread dumps are saved."
	echo "	-n (optional): Number of thread dumps to generate."
	echo "	-s (optional): Sleep in seconds between two thread dump generation."
	echo ""
	echo "Example: ${0} -d \"${THREAD_DUMP_DIR}\" -n ${NUMBER_OF_THREAD_DUMPS} -s ${SLEEP}"

	exit 2
}

main "${@}"