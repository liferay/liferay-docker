#!/bin/bash

function check_usage {
	NUMBER_OF_THREAD_DUMPS=20
	SLEEP=5
	THREAD_DUMPS_DIR="${LIFERAY_HOME}/data/sre/thread_dumps"

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				THREAD_DUMPS_DIR=${1}

				;;
			-h)
				print_help

				;;
			-n)
				shift

				NUMBER_OF_THREAD_DUMPS=${1}

				;;
			-s)
				shift

				SLEEP=${1}

				;;
			*)
				print_help

				;;
		esac

		shift
	done
}

generate_thread_dump() {
	local date=$(date +'%Y-%m-%d')

	mkdir -p "${THREAD_DUMPS_DIR}/${date}"

	local id=${2}
	local time=$(date +'%H-%M-%S')

	echo "[Liferay] Generating ${THREAD_DUMPS_DIR}/${date}/thread_dump-${time}-${id}.txt"

	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)

	echo -e "${thread_dump}" > "${THREAD_DUMPS_DIR}/${date}/thread_dump-${time}-${id}.txt"
}

main() {
	check_usage "${@}"

	for i in $(seq 1 ${NUMBER_OF_THREAD_DUMPS})
	do
		generate_thread_dump ${i}

		sleep ${SLEEP}
	done

	echo "[Liferay] Generated thread dumps"
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Directory path to which the thread dumps are saved"
	echo "	-n (optional): Number of thread dumps to generate"
	echo "	-s (optional): Sleep in seconds between two thread dumps"
	echo ""
	echo "Example: ${0} -d \"${THREAD_DUMPS_DIR}\" -n ${NUMBER_OF_THREAD_DUMPS} -s ${SLEEP}"

	exit 2
}

main "${@}"