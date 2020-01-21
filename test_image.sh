#!/bin/bash

source ./_common.sh

function check_usage {
	if [ ! -n "${LIFERAY_DOCKER_IMAGE_ID}" ]
	then
		echo "Usage: ${0}"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_DOCKER_IMAGE_ID: ID of Docker image"
		echo ""
		echo "Example: LIFERAY_DOCKER_IMAGE_ID=liferay/dxp:7.2.10.1-sp1-202001171544 ${0}"

		exit 1
	fi

	check_utils curl docker
}

function log_test_result {
	local result=SUCCESS

	if [ ${1} -gt 0 ]
	then
		TEST_RESULT=1
		result=FAILED
	fi

	echo "Test result: [${FUNCNAME[1]}] ${result}: ${2}"
}

function main {
	check_usage

	make_temp_directory -test

	start_container

	test_verify_healthy_status

	test_docker_image_files

	test_docker_image_scripts

	stop_container

	clean_up_temp_directory

	exit ${TEST_RESULT}
}

function start_container {
	echo "Starting container from image ${LIFERAY_DOCKER_IMAGE_ID}."

	local mount_full_path=`pwd`/${TEMP_DIR}

	CONTAINER_ID=`docker run -d -p 8080 -v ${mount_full_path}:/mnt/liferay ${LIFERAY_DOCKER_IMAGE_ID}`

	CONTAINER_PORT_HTTP=`docker port ${CONTAINER_ID} 8080/tcp`

	CONTAINER_PORT_HTTP=${CONTAINER_PORT_HTTP##*:}
}

function stop_container {
	echo "Stopping container."

	docker kill ${CONTAINER_ID} > /dev/null
	docker rm ${CONTAINER_ID} > /dev/null
}

function test_docker_image_files {
	local http_response=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_files.jsp`

	if [ "${http_response}" == "TEST" ]
	then
		log_test_result 0 "The JSP content was returned correctly."

		return 0
	else
		log_test_result 1 "Incorrect response from http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_files.jsp"

		return 1
	fi
}

function test_docker_image_scripts {
	local http_response=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_files.jsp`

	if [ "${http_response}" == "TEST2" ]
	then
		log_test_result 0 "The content produced by the test scripts was correct."

		return 0
	else
		log_test_result 1 "Incorrect response after checking the scripts output."

		return 1
	fi
}

function test_verify_healthy_status {
	echo -en "Waiting for healthy status report"

	for counter in {1..30}
	do
		echo -en "."

		local status=`docker inspect --format='{{json .State.Health.Status}}' ${CONTAINER_ID}`

		if [ "${status}" == "\"healthy\"" ]; then
			echo ""

			log_test_result 0 "Container reported healthy result."

			return 0
		fi

		sleep 3
	done

	echo ""

	log_test_result 1 "Container failed to report healthy result before timeout reached. Last status: ${status}."

	return 1
}

main ${@}