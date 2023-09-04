#!/bin/bash

source ./_common.sh

function check_usage {
	if [ ! -n "${LIFERAY_DOCKER_IMAGE_ID}" ] || [ ! -n "${LIFERAY_DOCKER_LOGS_DIR}" ]
	then
		echo "Usage: ${0}"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_DOCKER_IMAGE_ID: ID of Docker image"
		echo "    LIFERAY_DOCKER_LOGS_DIR: Path to the logs directory"
		echo ""
		echo "Example: LIFERAY_DOCKER_IMAGE_ID=liferay/caddy LIFERAY_DOCKER_LOGS_DIR=logs-202306270130 ${0}"

		exit 1
	fi

	check_utils curl docker
}

function clean_up_test_directory {
	if [ "${TEST_RESULT}" -eq 0 ]
	then
		rm -fr "${TEST_DIR}"
	fi
}

function generate_logs {
	if [ "${TEST_RESULT}" -gt 0 ]
	then
        mkdir -p "${PWD}/${LIFERAY_DOCKER_LOGS_DIR}"
		docker logs "${CONTAINER_ID}" > "${PWD}/${LIFERAY_DOCKER_LOGS_DIR}/test.log" 2>&1
	fi
}

function log_test_failure {
	TEST_RESULT=1

	if [ -n "${1}" ]
	then
		echo "[${1}] FAILED"
	else
		echo "[${FUNCNAME[1]}] FAILED"
	fi
}

function log_test_success {
    TEST_RESULT=0
	
	if [ -n "${1}" ]
	then
		echo "[${1}] SUCCESS"
	else
		echo "[${FUNCNAME[1]}] SUCCESS"
	fi
}

function main {
	check_usage

	prepare_mount

	start_container

	test_health_status

	test_docker_image_files

	generate_logs

	stop_container

	clean_up_test_directory

	exit "${TEST_RESULT}"
}

function prepare_mount {
    local timestamp=$(date "$(date)" "+%Y%m%d%H%M")

	TEST_DIR="${PWD}/temp-test-${timestamp}"

	mkdir -p "${TEST_DIR}"

    echo "<html>HELLO</html>" > "${TEST_DIR}/index.html"
}

function start_container {
	echo "Starting container from image ${LIFERAY_DOCKER_IMAGE_ID}."

	CONTAINER_ID=$(docker run -d -p 8080:80 -v "${TEST_DIR}:/public_html" "${LIFERAY_DOCKER_IMAGE_ID}")
}

function stop_container {
	echo "Stopping container."

	docker kill "${CONTAINER_ID}" > /dev/null
	docker rm "${CONTAINER_ID}" > /dev/null
}

function test_docker_image_files {
	test_page http://localhost:8080/index.html "HELLO"
}

function test_health_status {
	echo -en "Waiting for health status"

	for counter in {1..200}
	do
		echo -en "."

		local health_status=$(docker inspect --format="{{json .State.Status}}" "${CONTAINER_ID}")
		local serving_status=$(docker logs "${CONTAINER_ID}" 2>&1 | grep -c "serving initial configuration")

		if [ "${health_status}" == "\"running\"" ] && [ "${serving_status}" -gt 0 ]
		then
			echo ""

			log_test_success

			return
		fi

		sleep 3
	done

	echo ""

	log_test_failure

	echo "Container health status is: ${health_status}."
}

function test_page {
	local content

	content=$(curl --fail --max-time 60 -s --show-error -L "${1}")

	local exit_code=$?

	if [ ${exit_code} -gt 0 ]
	then
		log_test_failure "${FUNCNAME[1]}"

		echo "${content}"
		echo ""
		echo "curl exit code is: ${exit_code}."
	else
		if [[ "${content}" =~ .*"${2}".* ]]
		then
			log_test_success "${FUNCNAME[1]}"
		else
			log_test_failure "${FUNCNAME[1]}"

			echo "${content}"
			echo ""
			echo "The \"${2}\" string is not present on the page."
		fi
	fi
}

main "${@}"