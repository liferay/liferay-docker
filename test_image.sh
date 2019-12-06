#!/bin/bash

source ./_common.sh

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
	make_temp_directory -test

	start_container

	test_verify_healthy_status

	test_files_docker_test_jsp

	stop_container

	clean_up_temp_directory

	exit ${TEST_RESULT}
}

function start_container {
	echo "Starting up the container from the ${LIFERAY_DOCKER_IMAGE_ID} image."

	local mount_full_path=`pwd`/${TEMP_DIR}

	CONTAINER_ID=`docker run -d -p 8080 -v ${mount_full_path}:/mnt/liferay ${LIFERAY_DOCKER_IMAGE_ID}`
	CONTAINER_PORT_HTTP=`docker port ${CONTAINER_ID} 8080/tcp`

	CONTAINER_PORT_HTTP=${CONTAINER_PORT_HTTP##*:}
}

function stop_container {
	echo "Stopping the container."

	docker kill ${CONTAINER_ID} > /dev/null
	docker rm ${CONTAINER_ID} > /dev/null
}

function test_files_docker_test_jsp {
	local jsp_response=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/docker_test.jsp`

	if [ ${jsp_response} == "TEST" ]
	then
		log_test_result 0 "The JSP content was returned correctly."

		return 0
	else
		log_test_result 1 "Incorrect response from http://localhost:${CONTAINER_PORT_HTTP}/docker_test.jsp"

		return 1
	fi
}

function test_verify_healthy_status {
	echo -en "Waiting for healthy status report"

	for counter in {1..30}
	do
		echo -en "."

		local status=`docker inspect --format='{{json .State.Health.Status}}' $CONTAINER_ID`

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