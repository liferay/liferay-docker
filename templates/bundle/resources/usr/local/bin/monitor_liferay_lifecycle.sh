#!/bin/bash

source /usr/local/bin/_liferay_bundle_common.sh

function generate_thread_dump {
	local thread_dump=$(jattach $(cat "${LIFERAY_PID}") threaddump)

	mkdir -p "${LIFERAY_THREAD_DUMPS_DIRECTORY}"

	local file_name="${LIFERAY_THREAD_DUMPS_DIRECTORY}/$(hostname)_$(date +'%Y-%m-%d_%H-%M-%S').tdump"

	echo -e "${thread_dump}" > "${file_name}"

	echo '"{'$(cat "${file_name}")'"}' > /proc/1/fd/1

	lecho "Generated a thread dump at ${file_name}."
}

function lecho {
	echo -en "Lifecycle monitor: "

	echo "${@}"
}

function kill_service {
	lecho "Killing container since it reached the LIFERAY_CONTAINER_KILL_ON_FAILURE threshold."

	kill $(cat "${LIFERAY_PID}")

	lecho "Waiting 30 seconds for shut down."

	sleep 30

	lecho "Forcefully killing the Liferay service in the container."

	kill -9 $(cat "${LIFERAY_PID}")
}

function main {
	local curl_max_time=$((LIFERAY_CONTAINER_STATUS_REQUEST_TIMEOUT + 10))
	local fail_count=0
	local modules_active=false
	local started=false

	update_container_status liferay-start

	if [ -z "${LIFERAY_CONTAINER_STATUS_ACTIVE_MODULES}" ]
	then
		modules_active=true
	fi

	while true
	do
		if [ "${started}" != true ]
		then
			touch_startup_lock
		fi

		local curl_content

		curl_content=$(curl --connect-timeout "${LIFERAY_CONTAINER_STATUS_REQUEST_TIMEOUT}" --connect-to ":80:localhost:8080" --fail --max-time "${curl_max_time}" --show-error --silent "${LIFERAY_CONTAINER_STATUS_REQUEST_URL}" 2>/dev/null)

		local exit_code=${?}

		if [ ${exit_code} -gt 0 ]
		then
			if [ "${started}" == "true" ]
			then
				generate_thread_dump

				update_container_status fail,http-response-error,curl-return-code-${exit_code}
			fi
		elif [ -n "${LIFERAY_CONTAINER_STATUS_REQUEST_CONTENT}" ]
		then
			curl_content=$(echo "${curl_content}" | grep "${LIFERAY_CONTAINER_STATUS_REQUEST_CONTENT}")

			exit_code=${?}

			if [ ${exit_code} -gt 0 ] && [ "${started}" == "true" ]
			then
				generate_thread_dump

				update_container_status fail,content-missing
			fi
		fi

		if [ ${exit_code} -eq 0 ]
		then
			fail_count=0

			started=true

			if [ "${modules_active}" == "true" ]
			then
				update_container_status live
			else
				update_container_status waiting-for-modules-to-become-active
			fi
		fi

		if [ "${modules_active}" == "false" ] && [ "${started}" == "true" ]
		then
			telnet_content=$(
				(
					sleep 1
					echo "ss"
					sleep 2
				) | telnet 127.0.0.1 11311 2>/dev/null
			)

			local active_count=$(echo "${telnet_content}" | grep -E "${LIFERAY_CONTAINER_STATUS_ACTIVE_MODULES}" | grep -c ACTIVE)

			local module_count=$(echo "${telnet_content}" | grep -cE "${LIFERAY_CONTAINER_STATUS_ACTIVE_MODULES}")

			if [ "${module_count}" -eq 0 ]
			then
				echo "No modules are available yet with the following filter: ${LIFERAY_CONTAINER_STATUS_ACTIVE_MODULES}"
			elif [ "${module_count}" -eq "${active_count}" ]
			then
				update_container_status live

				modules_active=true
			else
				echo "Modules pending activation:"

				echo "${telnet_content}" | grep -E "${LIFERAY_CONTAINER_STATUS_ACTIVE_MODULES}" | grep -v ACTIVE
			fi
		fi

		if [ "${LIFERAY_CONTAINER_KILL_ON_FAILURE}" -gt 0 ] && [ ${exit_code} -gt 0 ] && [ "${started}" == "true" ]
		then
			fail_count=$((fail_count + 1))

			if [ "${fail_count}" -eq "${LIFERAY_CONTAINER_KILL_ON_FAILURE}" ]
			then
				kill_service
			fi
		fi

		if [ "${started}" != "true" ] || [ "${modules_active}" != "true" ]
		then
			sleep 3
		else
			sleep 30
		fi
	done
}

function remove_startup_lock {
	if [ -n "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ] && [ -e "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ]
	then
		rm -fr "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}"
	fi
}

function touch_startup_lock {
	if [ -n "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ] && [ -e "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}" ]
	then
		touch "${LIFERAY_CONTAINER_STARTUP_LOCK_FILE}"
	fi
}

main