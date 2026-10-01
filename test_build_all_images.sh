#!/bin/bash

source ./_liferay_common.sh
source ./_test_common.sh
source ./build_all_images.sh

function main {
	set_up

	if [[ "${#}" -eq 1 ]]
	then
		if [ "${1}" == "test_build_all_images_are_regular_containers_healthy" ] ||
		   [ "${1}" == "test_build_all_images_is_cms_standalone_container_healthy" ]
		then
			"${1}"
		elif [ "${1}" == "test_build_all_images_has_cms_standalone_tag" ]
		then
			test_build_all_images_is_cms_standalone_container_healthy

			"${1}"
		else
			test_build_all_images_are_regular_containers_healthy

			"${1}"
		fi
	else
		test_build_all_images_are_regular_containers_healthy

		test_build_all_images_get_latest_available_zulu_version
		test_build_all_images_has_slim_build_criteria
		test_build_all_images_latest_is_not_slim
		test_build_all_images_trial_license_is_deleted

		test_build_all_images_is_cms_standalone_container_healthy

		test_build_all_images_has_cms_standalone_tag
	fi

	tear_down
}

function set_up {
	export _LATEST_RELEASE=$(yq eval ".quarterly | keys | .[-1]" "${PWD}/bundles.yml")

	rm --force --recursive logs-*
}

function tear_down {
	docker rmi $(docker images --filter "dangling=true" --no-trunc) &> /dev/null
	docker rmi --force "liferay/dxp:cms-standalone-weekly" &> /dev/null
	docker rmi --force "liferay/jdk11-jdk8:latest" &> /dev/null
	docker rmi --force "liferay/jdk11:latest" &> /dev/null
	docker rmi --force "liferay/jdk21-jdk11-jdk8:latest" &> /dev/null
	docker rmi --force "liferay/jdk21:latest" &> /dev/null
	docker rmi --force $(docker images "liferay/dxp:${_LATEST_RELEASE}-slim") &> /dev/null

	local file

	for file in $(find $(find . -name "logs-*" -type d) -name "build*image_id.txt" -type f)
	do
		docker rmi --force $(cat "${file}" | cut --delimiter=':' --fields=2) &> /dev/null
	done

	unset _LATEST_RELEASE
}

function test_build_all_images_are_regular_containers_healthy {
	_test_build_all_images_is_container_healthy "${_LATEST_RELEASE}" "true"
	_test_build_all_images_is_container_healthy "7.3.10-u36" "false"
}

function test_build_all_images_get_latest_available_zulu_version {
	_test_build_all_images_get_latest_available_zulu_version "amd64" "8"
	_test_build_all_images_get_latest_available_zulu_version "arm64" "8"
	_test_build_all_images_get_latest_available_zulu_version "amd64" "11"
	_test_build_all_images_get_latest_available_zulu_version "arm64" "11"
	_test_build_all_images_get_latest_available_zulu_version "amd64" "21"
	_test_build_all_images_get_latest_available_zulu_version "arm64" "21"
}

function test_build_all_images_has_cms_standalone_tag {
	assert_equals \
		"$(docker images --format "{{.Repository}}:{{.Tag}}" "liferay/dxp:cms-standalone-weekly")" \
		"liferay/dxp:cms-standalone-weekly"
}

function test_build_all_images_has_slim_build_criteria {
	_test_build_all_images_has_slim_build_criteria "2024.q2.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "2025.q1.11-lts" "${LIFERAY_COMMON_EXIT_CODE_OK}"
	_test_build_all_images_has_slim_build_criteria "7.4.13-u124" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.13.nightly" "${LIFERAY_COMMON_EXIT_CODE_OK}"
}

function test_build_all_images_is_cms_standalone_container_healthy {
	_test_build_all_images_is_container_healthy "cms-standalone-weekly" "false"
}

function test_build_all_images_latest_is_not_slim {
	assert_equals \
		$(docker images --format "{{.Repository}}:{{.Tag}}" "liferay/dxp:${_LATEST_RELEASE}") \
		"liferay/dxp:${_LATEST_RELEASE}" \
		$(docker images --filter "reference=liferay/dxp:${_LATEST_RELEASE}" --format "{{.ID}}") \
		$(docker images --filter "reference=liferay/dxp:latest" --format "{{.ID}}")
}

function test_build_all_images_trial_license_is_deleted {
	_test_build_all_images_trial_license_is_deleted "${_LATEST_RELEASE}" "false" "1"
	_test_build_all_images_trial_license_is_deleted "${_LATEST_RELEASE}" "true" "0"
}

function _test_build_all_images_get_latest_available_zulu_version {
	local latest_available_zulu_version=$(get_latest_available_zulu_version "${1}" "${2}")

	assert_equals \
		"${latest_available_zulu_version}" \
		$( \
			curl \
				--header 'accept: */*' \
				--location \
				--silent \
				"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?arch=${1}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=${2}&os=linux" | \
			jq --raw-output '.zulu_version | join(".")' | \
			cut --delimiter='.' --fields=1,2,3)
}

function _test_build_all_images_has_slim_build_criteria {
	has_slim_build_criteria "${1}"

	assert_equals "${?}" "${2}"
}

function _test_build_all_images_is_container_healthy {
	mkdir --parents "logs-${1}"

	LIFERAY_DOCKER_IMAGE_FILTER="${1}" LIFERAY_DOCKER_LOGS_DIR="logs-${1}" build_bundle_images &> /dev/null

	assert_equals \
		"$(grep --count "\[test_health_status\] SUCCESS" "logs-${1}/${1}.log")" \
		"1"

	rm --force --recursive "logs-${1}"
}

function _test_build_all_images_trial_license_is_deleted {
	local trial_license_count=$( \
		docker run \
			--entrypoint bash \
			--env LIFERAY_CONTAINER_DISABLE_TRIAL_LICENSE="${2}" \
			--network none \
			--rm \
			"liferay/dxp:${1}" \
			-c 'configure_liferay.sh &> /dev/null

				ls \
					/opt/liferay/deploy/trial-dxp-license-*.xml \
					/opt/liferay/osgi/modules/trial-dxp-license-*.xml 2> /dev/null | \
				wc --lines')

	assert_equals "${trial_license_count}" "${3}"
}

main "${@}"