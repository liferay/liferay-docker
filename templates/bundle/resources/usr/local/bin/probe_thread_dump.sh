#!/bin/bash

function check_usage {
	CONNECTION_TIMEOUT=20
	FILE_PATH="/"
	PORT=8080
	TIMEOUT=25

	while [ "${1}" != "" ]
	do
		case ${1} in
			-c)
				shift

				CONTENT=${1}

				;;
			-d)
				shift

				DOMAIN=${1}

				;;
			-h)
				print_help

				;;
			-f)
				shift

				FILE_PATH=${1}

				;;
			-p)
				shift

				PORT=${1}

				;;
			-t)
				shift

				TIMEOUT=${1}

				;;
			-z)
				shift

				CONNECTION_TIMEOUT=${1}

				;;
			*)
				print_help

				;;
		esac

		shift
	done

	if [ ! -n "${DOMAIN}" ]
	then
		echo "The domain argument is required."

		exit 1
	fi
}

function main {
	if [ "${LIFERAY_THREAD_DUMP_PROBE_ENABLED}" != "true" ]
	then
		echo "Set the environment variable \"LIFERAY_THREAD_DUMP_PROBE_ENABLED\" to \"true\" to enable ${0}."

		exit 1
	fi

	check_usage "${@}"

	local curl_content

	curl_content=$(curl --connect-timeout "${CONNECTION_TIMEOUT}" --fail --max-time "${TIMEOUT}" --show-error --silent --url "${DOMAIN}:${PORT}" "${DOMAIN}:${PORT}${FILE_PATH}")

	local exit_code=$?

	if [ -n "${CONTENT}" ]
	then
		curl_content=$(echo "${curl_content}" | grep" ${CONTENT}")

		exit_code=$?
	fi

	if [ ${exit_code} -gt 1 ]
	then
		echo -e "${curl_content}"

		local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)

		if [ ! -e  "${LIFERAY_THREAD_DUMPS_DIRECTORY}" ]
		then
			mkdir -p "${LIFERAY_THREAD_DUMPS_DIRECTORY}"
		fi

		echo -e "${thread_dump}" > "${LIFERAY_THREAD_DUMPS_DIRECTORY}/$(hostname)_$(date +'%Y-%m-%d_%H-%M-%S').tdump"
	fi

	exit ${exit_code}
}

function print_help {
	echo "Usage: ${0} -c <content> -d <domain> -f <path> -p <port> -t <timeout> -z <connection-timeout>"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "  -c (optional): Content that the response must contain"
	echo "	-d (required): Domain of the URL to check"
	echo "	-f (optional): Path of the URL to check"
	echo "  -p (optional): HTTP port of the URL to check"
	echo "	-t (optional): Timeout in seconds"
	echo "	-z (optional): Connection timeout in seconds"
	echo ""
	echo "Example: ${0} -d \"http://localhost\" -f \"/c/portal/layout\"" -p 8080 -t 20

	exit 2
}

main "${@}"