#!/bin/bash

source ./_common.sh
source ./_env_common.sh

function check_usage {
	if [ ! -n "${LIFERAY_DOCKER_IMAGE_ID}" ] || [ ! -n "${LIFERAY_DOCKER_LOGS_DIR}" ]
	then
		echo "Usage: ${0}"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_DOCKER_IMAGE_ID: ID of Docker image"
		echo "    LIFERAY_DOCKER_LOGS_DIR: Path to the logs directory"
		echo "    LIFERAY_DOCKER_NETWORK_NAME: Docker network name of the CI node container"
		echo "    LIFERAY_DOCKER_TEST_HOTFIX_URL: URL of the test hotfix to install"
		echo "    LIFERAY_DOCKER_TEST_INSTALLED_PATCHES: Comma separated list of installed patches (e.g. dxp-4-7210,hotfix-1072-7210)"
		echo "    LIFERAY_DOCKER_TEST_NAME: Test name (e.g. test_docker_image_files)"
		echo "    LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL: URL of the test Patching Tool to install"
		echo ""
		echo "Example: LIFERAY_DOCKER_IMAGE_ID=liferay/dxp:7.2.10.1-sp1-202001171544 LIFERAY_DOCKER_LOGS_DIR=logs-202306270130 ${0}"

		exit 1
	fi

	check_utils curl docker
}

function clean_up_test_directory {
	if [ "${TEST_RESULT}" -eq 0 ]
	then
		rm --force --recursive "${TEST_DIR}"
	fi

	if [ -d "/opt/dev/projects/github/${TEST_DIR}" ]
	then
		rm --force --recursive "/opt/dev/projects/github/${TEST_DIR}"
	fi
}

function generate_thread_dump {
	if [ "${TEST_RESULT}" -gt 0 ]
	then
		docker exec --interactive --tty "${CONTAINER_ID}" /usr/local/bin/generate_thread_dump.sh

		docker cp "${CONTAINER_ID}":/opt/liferay/data/sre/thread_dumps "${PWD}/${LIFERAY_DOCKER_LOGS_DIR}"
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

	if [ -n "${LIFERAY_DOCKER_TEST_NAME}" ]
	then
		if [ "${LIFERAY_DOCKER_TEST_NAME}" == "test_health_status" ]
		then
			"${LIFERAY_DOCKER_TEST_NAME}"
		else
			test_health_status

			"${LIFERAY_DOCKER_TEST_NAME}"
		fi
	else
		test_health_status

		test_docker_image_files
		test_docker_image_fix_pack_installed
		test_docker_image_hotfix_installed
		test_docker_image_patching_tool_updated
		test_docker_image_scripts_1
		test_docker_image_scripts_2
	fi

	generate_thread_dump

	stop_container

	clean_up_test_directory

	exit "${TEST_RESULT}"
}

function prepare_mount {
	TEST_DIR=temp-test-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir --parents "${TEST_DIR}"

	cp --recursive templates/test/resources/* "${TEST_DIR}"

	mkdir --parents "${TEST_DIR}/mnt/liferay/patching"

	if [ -n "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL}" ]
	then
		local patching_tool_file_name=${LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL##*/}

		download "downloads/patching-tool/${patching_tool_file_name}" "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL}"
	fi

	if [ -n "${LIFERAY_DOCKER_TEST_HOTFIX_URL}" ]
	then
		local hotfix_file_name=${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}

		download "downloads/hotfix/${hotfix_file_name}" "${LIFERAY_DOCKER_TEST_HOTFIX_URL}"

		cp "downloads/hotfix/${hotfix_file_name}" "${TEST_DIR}/mnt/liferay/patching"
	fi

	if [ -n "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}" ]
	then
		download "downloads/patching-tool/patching-tool-${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}.zip" "files.liferay.com/private/ee/fix-packs/patching-tool/patching-tool-${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}.zip"

		cp "downloads/patching-tool/patching-tool-${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}.zip" "${TEST_DIR}/mnt/liferay/patching/"
	fi

	if [ -e "${TEST_DIR}/mnt/liferay/scripts" ]
	then
		chmod --recursive +x "${TEST_DIR}/mnt/liferay/scripts"
	fi
}

function start_container {
	echo "Starting container from image ${LIFERAY_DOCKER_IMAGE_ID}."

	# TODO Temporary fix until IT rebuilds the CI servers

	if [ ! -n "${LIFERAY_DOCKER_NETWORK_NAME}" ]
	then
		LIFERAY_DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME}"
	fi

	CONTAINER_HOSTNAME="localhost"

	local test_dir="${PWD}/${TEST_DIR}"

	local parameters="--env=LIFERAY_DOCKER_TEST_MODE=true --publish=8080 --volume=${test_dir}/mnt:/mnt:rw"

	if [ -n "${LIFERAY_DOCKER_NETWORK_NAME}" ]
	then
		if [ "$(get_environment_type "${LIFERAY_DOCKER_NETWORK_NAME}")" == "ci_slave" ]
		then
			CONTAINER_HOSTNAME=portal-container
			CONTAINER_HTTP_PORT=8080

			echo -e "web.server.host=${CONTAINER_HOSTNAME}" > "/opt/dev/projects/github/portal-ext.properties"

			mv "${PWD}/${TEST_DIR}" "/opt/dev/projects/github"

			parameters="--env=LIFERAY_DOCKER_TEST_MODE=true --hostname=${CONTAINER_HOSTNAME} --name=${CONTAINER_HOSTNAME} --network=${LIFERAY_DOCKER_NETWORK_NAME} --publish=8081:8080 --volume=/data/${LIFERAY_DOCKER_NETWORK_NAME}/liferay/${TEST_DIR}/mnt:/mnt:rw --volume=/data/${LIFERAY_DOCKER_NETWORK_NAME}/liferay/portal-ext.properties:/opt/liferay/portal-ext.properties"
		elif [ "$(get_environment_type "${LIFERAY_DOCKER_NETWORK_NAME}")" == "release_slave" ]
		then
			CONTAINER_HOSTNAME=$(docker network inspect bridge --format='{{(index .IPAM.Config 0).Gateway}}')
			CONTAINER_HTTP_PORT=8081

			echo -e "web.server.host=${CONTAINER_HOSTNAME}\nweb.server.http.port=8081" > "${TEST_DIR}/portal-ext.properties"

			cp --recursive "${TEST_DIR}" "/opt/dev/projects/github/liferay-docker"

			test_dir="/mnt/pd/liferay-docker/${TEST_DIR}"

			parameters="--env=LIFERAY_DOCKER_TEST_MODE=true --hostname=${CONTAINER_HOSTNAME} --name=${CONTAINER_HOSTNAME} --network=${LIFERAY_DOCKER_NETWORK_NAME} --publish=8081:8080 --volume=${test_dir}/mnt:/mnt:rw --volume=${test_dir}/portal-ext.properties:/opt/liferay/portal-ext.properties"
		else
			CONTAINER_HOSTNAME=portal-container
			CONTAINER_HTTP_PORT=8080

			test_dir="/data/${LIFERAY_DOCKER_NETWORK_NAME}/liferay/liferay-docker/${TEST_DIR}"

			parameters="--env=LIFERAY_DOCKER_TEST_MODE=true --hostname=${CONTAINER_HOSTNAME} --name=${CONTAINER_HOSTNAME} --network=${LIFERAY_DOCKER_NETWORK_NAME} --publish=8080 --volume=${test_dir}/mnt:/mnt:rw"
		fi
	fi

	CONTAINER_ID=$(docker run --detach ${parameters} "${LIFERAY_DOCKER_IMAGE_ID}")

	if [ ! -n "${LIFERAY_DOCKER_NETWORK_NAME}" ]
	then
		CONTAINER_HTTP_PORT=$(docker port "${CONTAINER_ID}" 8080/tcp)

		CONTAINER_HTTP_PORT=${CONTAINER_HTTP_PORT##*:}
	fi

	TEST_RESULT=0
}

function stop_container {
	echo "Stopping container."

	docker kill "${CONTAINER_ID}" > /dev/null
	docker rm "${CONTAINER_ID}" > /dev/null
}

function test_docker_image_files {
	test_page "http://${CONTAINER_HOSTNAME}:${CONTAINER_HTTP_PORT}/test_docker_image_files.jsp" "TEST"
}

function test_docker_image_fix_pack_installed {
	if [ -n "${LIFERAY_DOCKER_TEST_INSTALLED_PATCHES}" ]
	then
		local correct_fix_pack=$(echo "${LIFERAY_DOCKER_TEST_INSTALLED_PATCHES}" | tr -d '[:space:]')
		local output=$(docker exec --interactive --tty "${CONTAINER_ID}" /opt/liferay/patching-tool/patching-tool.sh info | grep "Currently installed patches:")

		local installed_fix_pack=$(echo "${output##*: }" | tr --delete '[:space:]')

		if [ "${correct_fix_pack}" == "${installed_fix_pack}" ]
		then
			log_test_success
		else
			log_test_failure

			echo "The installed patch (${correct_fix_pack}) does not match the patch version retrived from the Patching Tool in the container (${installed_fix_pack})."
		fi
	else
		log_test_success
	fi
}

function test_docker_image_hotfix_installed {
	if [ -n "${LIFERAY_DOCKER_TEST_HOTFIX_URL}" ]
	then
		test_page "http://${CONTAINER_HOSTNAME}:${CONTAINER_HTTP_PORT}/" "Hotfix installation on the Docker image was successful."
	fi
}

function test_docker_image_patching_tool_updated {
	if [ -n "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}" ]
	then
		local output=$(docker logs --details "${CONTAINER_ID}" 2>/dev/null)

		if [[ "${output}" =~ .*"Patching Tool updated successfully".* ]]
		then
			log_test_success
		else
			log_test_failure

			echo "Unable to update the Patching Tool."
		fi
	fi
}

function test_docker_image_scripts_1 {
	test_page "http://${CONTAINER_HOSTNAME}:${CONTAINER_HTTP_PORT}/test_docker_image_scripts_1.jsp" "TEST1"
}

function test_docker_image_scripts_2 {
	test_page "http://${CONTAINER_HOSTNAME}:${CONTAINER_HTTP_PORT}/test_docker_image_scripts_2.jsp" "TEST2"
}

function test_health_status {
	echo -en "Waiting for health status"

	for counter in {1..200}
	do
		echo -en "."

		local health_status=$(docker inspect --format="{{json .State.Health.Status}}" "${CONTAINER_ID}")
		local ignore_license=$(docker logs ${CONTAINER_ID} 2> /dev/null | grep --count "Starting Liferay Portal")
		local license_status=$(docker logs ${CONTAINER_ID} 2> /dev/null | grep --count "License registered for DXP Development")

		if [ "${health_status}" == "\"healthy\"" ] && ([ ${ignore_license} -gt 0 ] || [ ${license_status} -gt 0 ])
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

	content=$(curl --fail --location --max-time 60 --show-error --silent "${1}")

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