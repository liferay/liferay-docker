#!/bin/bash

function check_usage {
	DELAY=5
	NUMBER_OF_THREAD_DUMPS=20
	THREAD_DUMP_FOLDER="${LIFERAY_HOME}/data/thread_dumps"

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				DELAY=${1}

				;;
			-f)
				shift

				THREAD_DUMP_FOLDER=${1}

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
	local time=$(date +'%H%M%S')
	
	mkdir -p "${THREAD_DUMP_FOLDER}/${time}"

	echo "[Liferay] Generating ${THREAD_DUMP_FOLDER}/${time}/threaddump${id}.txt"

	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)
	 echo -e "${thread_dump}" > "${THREAD_DUMP_FOLDER}/${time}/threaddump${id}.txt"
}

main() {
	check_usage "${@}"

	if [ ! -e "${THREAD_DUMP_FOLDER}" ]
	then
		mkdir -p "${THREAD_DUMP_FOLDER}"
	fi

	for i in $(seq 1 $NUMBER_OF_THREAD_DUMPS)
	do
		generate_thread_dump $i
		sleep $DELAY
	done

	echo "[Liferay] Thread dumps generated"
}

function print_help {
	echo "Usage: ${0} -t <thread_dump_folder>"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "	-d (optional): Delay in seconds between two thread dump generation."
	echo "	-f (optional): Folder path to which the thread dumps are saved."
	echo "	-n (optional): Number of thread dumps to generate."
	echo ""
	echo "Example: ${0} -d 10 -n 30 -t \"${LIFERAY_HOME}/my_thread_dumps_folder\""

	exit 2
}

main "${@}"