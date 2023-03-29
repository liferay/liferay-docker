#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function generate_thread_dump {
	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)

	mkdir -p "${LIFERAY_THREAD_DUMPS_DIRECTORY}"

	local file_name="${LIFERAY_THREAD_DUMPS_DIRECTORY}/$(hostname)_$(date +'%Y-%m-%d_%H-%M-%S').tdump"

	echo -e "${thread_dump}" > "${file_name}"

	echo "Generated a thread dump at ${file_name}."
}

function kill_service {
	echo "Killing container since it reached the LIFERAY_CONTAINER_KILL_ON_FAILURE threshold."

	kill $(cat "${LIFERAY_PID}")

	echo "Waiting 30 seconds for shut down."

	sleep 30

	echo "Forcefully killing the Liferay service in the container."

	kill -9 $(cat "${LIFERAY_PID}")
}

function monitor_responsiveness {
	sleep 20

	local fail_count=0

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
			fail_count=0

			update_container_status live
		fi

		if [ "${LIFERAY_CONTAINER_KILL_ON_FAILURE}" -gt 0 ] && [ ${exit_code} -gt 0 ]
		then
			fail_count=$((fail_count + 1))

			if [ "${fail_count}" -eq "${LIFERAY_CONTAINER_KILL_ON_FAILURE}" ]
			then
				kill_service
			fi
		fi

		sleep 60
	done
}

function monitor_startup {
	sleep 10

	while (! cat /opt/liferay/tomcat/logs/* | grep "org.apache.catalina.startup.Catalina.start Server startup in" &>/dev/null)
	do
		touch_startup_lock

		sleep 3
	done

	update_container_status live

	remove_startup_lock
}

function main {
	monitor_startup

	monitor_responsiveness
}

function touch_startup_lock {
	if [ -n "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ] && [ -e "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ]
	then
		touch "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}"
	fi
}

function remove_startup_lock {
	if [ -n "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ] && [ -e "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ]
	then
		rm -fr "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}"
	fi
}

main