#!/bin/bash

source ./_liferay_common.sh
source ./_test_common.sh
source ./build_all_images.sh --test

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_build_all_images_get_latest_available_zulu_version
		test_build_all_images_has_slim_build_criteria
		test_build_all_images_is_container_healthy "${_LATEST_RELEASE}"
		test_build_all_images_is_container_healthy "7.3.10-u36"
		test_build_all_images_latest_is_not_slim "${_LATEST_RELEASE}"
	fi

	tear_down
}

function set_up {
	export _LATEST_RELEASE=$(yq eval ".quarterly | keys | .[-1]" "${PWD}/bundles.yml")

	LIFERAY_DOCKER_IMAGE_FILTER="${_LATEST_RELEASE}" LIFERAY_DOCKER_SLIM="true" ./build_all_images.sh &> /dev/null
	LIFERAY_DOCKER_IMAGE_FILTER="7.3.10-u36" ./build_all_images.sh &> /dev/null
}

function tear_down {
	docker stop "liferay-container-${_LATEST_RELEASE}" > /dev/null
	docker stop "liferay-container-7.3.10-u36" > /dev/null

	docker rm "liferay-container-${_LATEST_RELEASE}" > /dev/null
	docker rm "liferay-container-7.3.10-u36" > /dev/null

	docker rmi $(docker images --filter "dangling=true" --no-trunc) &> /dev/null
	docker rmi --force $(docker images "liferay/dxp:${_LATEST_RELEASE}-slim") &> /dev/null
	docker rmi --force "liferay/jdk11-jdk8:latest" &> /dev/null
	docker rmi --force "liferay/jdk11:latest" &> /dev/null
	docker rmi --force "liferay/jdk21-jdk11-jdk8:latest" &> /dev/null
	docker rmi --force "liferay/jdk21:latest" &> /dev/null

	for file in $(find $(find . -name "logs-20*" -type d) -name "build*image_id.txt" -type f)
	do
		docker rmi --force $(cat "${file}" | cut --delimiter=':' --fields=2) &> /dev/null
	done

	rm --force --recursive logs-20*

	unset _LATEST_RELEASE
}

function test_build_all_images_get_latest_available_zulu_version {
	_test_build_all_images_get_latest_available_zulu_version "amd64" "8"
	_test_build_all_images_get_latest_available_zulu_version "arm64" "8"
	_test_build_all_images_get_latest_available_zulu_version "amd64" "11"
	_test_build_all_images_get_latest_available_zulu_version "arm64" "11"
	_test_build_all_images_get_latest_available_zulu_version "amd64" "21"
	_test_build_all_images_get_latest_available_zulu_version "arm64" "21"
}

function test_build_all_images_has_slim_build_criteria {
	_test_build_all_images_has_slim_build_criteria "2024.q2.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "2025.q1.11-lts" "${LIFERAY_COMMON_EXIT_CODE_OK}"
	_test_build_all_images_has_slim_build_criteria "7.4.13-u124" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.13.nightly" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.3.132-ga132" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.3.142-ga142" "${LIFERAY_COMMON_EXIT_CODE_OK}"
}

function test_build_all_images_is_container_healthy {
	echo -e "Running test_build_all_images_is_container_healthy for version ${1}.\n"

	assert_equals \
		$(_run_container "${1}") \
		"\"healthy\""
}

function test_build_all_images_latest_is_not_slim {
	echo -e "Running test_build_all_images_latest_is_not_slim for version ${1}.\n"

	assert_equals \
		$(docker images --filter "reference=liferay/dxp:${1}" --format "{{.ID}}") \
		$(docker images --filter "reference=liferay/dxp:latest" --format "{{.ID}}")
}

function _run_container {
	local container_id=$(docker run --detach --name "liferay-container-${1}" "liferay/dxp:${1}")

	for counter in {1..200}
	do
		local health_status=$(docker inspect --format="{{json .State.Health.Status}}" "${container_id}")
		local license_status=$(docker logs ${container_id} 2> /dev/null | grep --count "License registered for DXP Development")
		local portal_start=$(docker logs ${container_id} 2> /dev/null | grep --count "Starting Liferay Portal")

		if [ "${health_status}" == "\"healthy\"" ] && ([ "${license_status}" -gt 0 ] || [ "${portal_start}" -gt 0 ])
		then
			echo "${health_status}"

			return
		fi

		sleep 3
	done

	echo "failed"
}

function _test_build_all_images_get_latest_available_zulu_version {
	echo -e "Running _test_get_latest_available_zulu_version for JDK ${1} ${2}.\n"

	local latest_available_zulu_version=$(get_latest_available_zulu_version "${1}" "${2}")

	assert_equals \
		"${latest_available_zulu_version}" \
		$(curl \
			--header 'accept: */*' \
			--location \
			--silent \
			"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?arch=${1}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=${2}&os=linux" | \
			jq --raw-output '.zulu_version | join(".")' | \
			cut --delimiter='.' --fields=1,2,3)
}

function _test_build_all_images_has_slim_build_criteria {
	echo -e "Running _test_build_all_images_has_slim_build_criteria for version ${1}.\n"

	has_slim_build_criteria "${1}"

	assert_equals "${?}" "${2}"
}

main "${@}"