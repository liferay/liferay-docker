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
		echo "    LIFERAY_DOCKER_TEST_HOTFIX_URL: URL of the test hotfix to be installed"
		echo "    LIFERAY_DOCKER_TEST_INSTALLED_PATCHES: Comma separated list of installed patches; fix pack, hotfix order (e.g. dxp-4-7210,hotfix-1072-7210)"
		echo ""
		echo "Example: LIFERAY_DOCKER_IMAGE_ID=liferay/dxp:7.2.10.1-sp1-202001171544 ${0}"

		exit 1
	fi

	check_utils curl docker
}

function log_test_result {
	local test_result=SUCCESS

	if [ ${1} -gt 0 ]
	then
		TEST_RESULT=1

		test_result=FAILED
	fi

	echo "[${FUNCNAME[1]}] ${test_result}"

	return ${1}
}

function main {
	check_usage

	prepare_mount

	start_container

	test_health_status

	test_docker_image_files
	test_docker_image_fix_pack_installed
	test_docker_image_hotfix_installed
	test_docker_image_scripts_1
	test_docker_image_scripts_2

	stop_container

	exit ${TEST_RESULT}
}

function prepare_mount {
	TEST_DIR=temp-test-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p ${TEST_DIR}

	cp -r test-template/* ${TEST_DIR}
	mkdir -p ${TEST_DIR}/patching

	local hotfix_file_name=${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}

	download_file releases/hotfix/${hotfix_file_name} ${LIFERAY_DOCKER_TEST_HOTFIX_URL}
	cp releases/hotfix/${hotfix_file_name} ${TEST_DIR}/patching/
}

function start_container {
	echo "Starting container from image ${LIFERAY_DOCKER_IMAGE_ID}."

	CONTAINER_ID=`docker run -d -p 8080 -v "${PWD}/${TEST_DIR}":/mnt/liferay ${LIFERAY_DOCKER_IMAGE_ID}`

	CONTAINER_PORT_HTTP=`docker port ${CONTAINER_ID} 8080/tcp`

	CONTAINER_PORT_HTTP=${CONTAINER_PORT_HTTP##*:}
}

function stop_container {
	echo "Stopping container."

	docker kill ${CONTAINER_ID} > /dev/null
	docker rm ${CONTAINER_ID} > /dev/null
}

function test_docker_image_files {
	local content=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_files.jsp`

	if [ "${content}" == "TEST" ]
	then
		log_test_result 0
	else
		log_test_result 1
	fi
}

function test_docker_image_fix_pack_installed {
	if [ -n "${LIFERAY_DOCKER_TEST_INSTALLED_PATCHES}" ]
	then
		local correct_fix_pack=$(echo ${LIFERAY_DOCKER_TEST_INSTALLED_PATCHES} | tr -d [:space:])
		local output=$(docker exec -it ${CONTAINER_ID} /opt/liferay/patching-tool/patching-tool.sh info | grep "Currently installed patches:")

		local installed_fix_pack=$(echo ${output##*: } | tr -d [:space:])

		if [ "${correct_fix_pack}" == "${installed_fix_pack}" ]
		then
			log_test_result 0
		else
			log_test_result 1
		fi
	else
		log_test_result 0
	fi
}

function test_docker_image_hotfix_installed {
	local content=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/`

	if [[ "${content}" == *"Hotfix installation on the docker image was successful."* ]]
	then
		log_test_result 0
	else
		log_test_result 1
		exit
	fi
}

function test_docker_image_scripts_1 {
	local content=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_scripts_1.jsp`

	if [ "${content}" == "TEST1" ]
	then
		log_test_result 0
	else
		log_test_result 1
	fi
}

function test_docker_image_scripts_2 {
	local content=`curl --fail --silent http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_scripts_2.jsp`

	if [ "${content}" == "TEST2" ]
	then
		log_test_result 0
	else
		log_test_result 1
	fi
}

function test_health_status {
	echo -en "Waiting for health status"

	for counter in {1..60}
	do
		echo -en "."

		local status=`docker inspect --format="{{json .State.Health.Status}}" ${CONTAINER_ID}`

		if [ "${status}" == "\"healthy\"" ]
		then
			echo ""

			log_test_result 0

			return
		fi

		sleep 3
	done

	echo ""

	log_test_result 1
}

main ${@}