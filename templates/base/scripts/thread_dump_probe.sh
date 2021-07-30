#!/bin/bash

function check_usage {
	FILE_PATH="/"
	PORT=8080
	TIMEOUT=20

	while [ "${1}" != "" ]
	do
		case $1 in
			-d)
				shift
				DOMAIN=${1}
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
			-c)
				shift
				CONTENT=${1}
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

	if [ ! -n "${DOMAIN}" ]
	then
		echo "Please set the domain parameter."

		exit 1
	fi
}

function main {
	check_usage "${@}"

	local curl_output
	curl_output=$(curl --show-error -s --url ${DOMAIN}:${PORT} -m ${TIMEOUT} ${DOMAIN}:${PORT}${FILE_PATH})
	local ret=$?

	if [ -n "${CONTENT}" ]
	then
		curl_output=$(echo "${curl_output}" | grep ${CONTENT})
		ret=$?
	fi

	if [ ${ret} -gt 1 ]
	then
		echo -e "${curl_output}"

		kill -3 $(ps -ef | grep org.apache.catalina.startup.Bootstrap | grep -v grep | awk '{ print $1 }')
	fi

	exit ${ret}
}

function print_help {
	echo "Usage: ${0} -d <domain> -c <content> -f <path> -p <port> -t <timeout> "
	echo ""
	echo "The script can be configured by using these parameters:"
	echo ""
	echo "	-d (required): the domain the site is responding to with valid content."
    echo "  -c (optional, default: skipping to check): checks if the site response contains this string."
	echo "	-f (optional, default: /): the path to check on the domain."
	echo "  -p (optional, default: 8080): the http port to check."
	echo "	-t (optional, default: 20): timeout in seconds."
	echo ""
	echo "Example: ${0} -d \"http://localhost\" -f \"/c/portal/layout\"" -p 8080 -t 20

	exit 2
}

main "${@}"