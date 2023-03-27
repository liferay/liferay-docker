#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function generate_thread_dump {
	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)

	mkdir -p "${LIFERAY_THREAD_DUMPS_DIRECTORY}"

	local file_name="${LIFERAY_THREAD_DUMPS_DIRECTORY}/$(hostname)_$(date +'%Y-%m-%d_%H-%M-%S').tdump"

	echo -e "${thread_dump}" > "${file_name}"

	echo "Generated thread dump to ${file_name}"
}

function monitor_responsiveness {
	sleep 20

	while (true)
	do
		local curl_content

		curl_content=$(curl --connect-timeout "${LIFERAY_CONTAINER_STATUS_REQUEST_TIMEOUT}" --fail --max-time "${LIFERAY_CONTAINER_STATUS_REQUEST_TIMEOUT}" --show-error --silent --url "localhost:8080" "${LIFERAY_CONTAINER_STATUS_REQUEST_URL}")

		local exit_code=$?

		if [ ${exit_code} -gt 0 ]
		then
			echo -e "${curl_content}"

			generate_thread_dump

			update_container_status fail,http-response-error,curl-return-code-${exit_code}
		elif [ -n "${LIFERAY_CONTAINER_STATUS_REQUEST_CONTENT}" ]
		then
			curl_content=$(echo "${curl_content}" | grep "${LIFERAY_CONTAINER_STATUS_REQUEST_CONTENT}")

			exit_code=$?

			if [ ${exit_code} -gt 0 ]
			then
				generate_thread_dump

				update_container_status fail,content-missing
			fi
		else
			update_container_status live
		fi

		sleep 60
	done
}

function monitor_startup {
	sleep 10

	while (! cat /opt/liferay/tomcat/logs/* | grep "org.apache.catalina.startup.Catalina.start Server startup in" &>/dev/null)
	do
		sleep 3
	done

	update_container_status live
}

function main {
	monitor_startup

	monitor_responsiveness
}

main