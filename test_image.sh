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
		echo "    LIFERAY_DOCKER_TEST_HOTFIX_URL: URL of the test hotfix to install"
		echo "    LIFERAY_DOCKER_TEST_INSTALLED_PATCHES: Comma separated list of installed patches (e.g. dxp-4-7210,hotfix-1072-7210)"
		echo "    LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL: URL of the test Patching Tool to install"
		echo ""
		echo "Example: LIFERAY_DOCKER_IMAGE_ID=liferay/dxp:7.2.10.1-sp1-202001171544 ${0}"

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

	test_health_status

	test_docker_image_files
	test_docker_image_fix_pack_installed
	test_docker_image_hotfix_installed
	test_docker_image_patching_tool_updated
	test_docker_image_scripts_1
	test_docker_image_scripts_2

	stop_container

	clean_up_test_directory

	exit "${TEST_RESULT}"
}

function prepare_mount {
	TEST_DIR=temp-test-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p "${TEST_DIR}"

	cp -r templates/test/* "${TEST_DIR}"

	mkdir -p "${TEST_DIR}/patching"

	if [ -n "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL}" ]
	then
		local patcing_tool_file_name=${LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL##*/}

		download "downloads/patching-tool/${patcing_tool_file_name}" "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_URL}"
	else
		local patcing_tool_file_name=$(find downloads/patching-tool/ -maxdepth 1 -name '*.zip' -printf "%T+\t%f\n" | sort | tail -n 1 | awk '{print $2}')
	fi

	if [ -n "${LIFERAY_DOCKER_TEST_HOTFIX_URL}" ]
	then
		local hotfix_file_name=${LIFERAY_DOCKER_TEST_HOTFIX_URL##*/}

		download "downloads/hotfix/${hotfix_file_name}" "${LIFERAY_DOCKER_TEST_HOTFIX_URL}"

		cp "downloads/hotfix/${hotfix_file_name}" "${TEST_DIR}/patching"
	fi

	if [ -n "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}" ]
	then
		download "downloads/patching-tool/patching-tool-${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}.zip" "files.liferay.com/private/ee/fix-packs/patching-tool/patching-tool-${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}.zip"

		cp "downloads/patching-tool/patching-tool-${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}.zip" "${TEST_DIR}/patching/"
	fi

	if [ -e "${TEST_DIR}/scripts" ]
	then
		chmod -R +x "${TEST_DIR}/scripts"
	fi
}

function start_container {
	echo "Starting container from image ${LIFERAY_DOCKER_IMAGE_ID}."

	CONTAINER_ID=$(docker run -d -p 8080 -v "${PWD}/${TEST_DIR}":/mnt/liferay "${LIFERAY_DOCKER_IMAGE_ID}")

	CONTAINER_PORT_HTTP=$(docker port "${CONTAINER_ID}" 8080/tcp)

	CONTAINER_PORT_HTTP=${CONTAINER_PORT_HTTP##*:}

	TEST_RESULT=0
}

function stop_container {
	echo "Stopping container."

	docker kill "${CONTAINER_ID}" > /dev/null
	docker rm "${CONTAINER_ID}" > /dev/null
}

function test_docker_image_files {
	test_page "http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_files.jsp" "TEST"
}

function test_docker_image_fix_pack_installed {
	if [ -n "${LIFERAY_DOCKER_TEST_INSTALLED_PATCHES}" ]
	then
		local correct_fix_pack=$(echo "${LIFERAY_DOCKER_TEST_INSTALLED_PATCHES}" | tr -d '[:space:]')
		local output=$(docker exec -it "${CONTAINER_ID}" /opt/liferay/patching-tool/patching-tool.sh info | grep "Currently installed patches:")

		local installed_fix_pack=$(echo "${output##*: }" | tr -d '[:space:]')

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
		test_page "http://localhost:${CONTAINER_PORT_HTTP}/" "Hotfix installation on the Docker image was successful."
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
	test_page "http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_scripts_1.jsp" "TEST1"
}

function test_docker_image_scripts_2 {
	test_page "http://localhost:${CONTAINER_PORT_HTTP}/test_docker_image_scripts_2.jsp" "TEST2"
}

function test_health_status {
	echo -en "Waiting for health status and license deployment"

	for counter in {1..200}
	do
		echo -en "."

		local license_status=$(docker logs ${CONTAINER_ID} 2> /dev/null | grep -c "License registered for DXP Development")
		local status=$(docker inspect --format="{{json .State.Health.Status}}" "${CONTAINER_ID}")

		if [ "${status}" == "\"healthy\"" ] && [ ${license_status} -gt 0 ]
		then
			echo ""

			log_test_success

			return
		fi

		sleep 3
	done

	echo ""

	log_test_failure

	echo "Container health status is: ${status}."
}

function test_page {
	local content

	content=$(curl --fail -s --show-error -L "${1}")

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