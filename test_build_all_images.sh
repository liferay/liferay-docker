#!/bin/bash

source build_all_images.sh --test
source _liferay_common.sh
source _test_common.sh

function main {
	test_build_all_images_get_latest_available_zulu_version
	test_build_all_images_has_slim_build_criteria
}

function test_build_all_images_get_latest_available_zulu_version {
	_test_build_all_images_get_latest_available_zulu_version "8" "amd64"
	_test_build_all_images_get_latest_available_zulu_version "8" "arm64"
	_test_build_all_images_get_latest_available_zulu_version "11" "amd64"
	_test_build_all_images_get_latest_available_zulu_version "11" "arm64"
	_test_build_all_images_get_latest_available_zulu_version "21" "amd64"
	_test_build_all_images_get_latest_available_zulu_version "21" "arm64"
}

function test_build_all_images_has_slim_build_criteria {
	_test_build_all_images_has_slim_build_criteria "2024.q2.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "2025.q1.11-lts" "${LIFERAY_COMMON_EXIT_CODE_OK}"
	_test_build_all_images_has_slim_build_criteria "7.4.13.nightly" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.13-u124" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.3.132-ga132" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_all_images_has_slim_build_criteria "7.4.3.142-ga142" "${LIFERAY_COMMON_EXIT_CODE_OK}"
}

function _test_build_all_images_get_latest_available_zulu_version {
	echo -e "Running _test_get_latest_available_zulu_version for JDK ${1} ${2}.\n"

	local latest_available_zulu_version=$(get_latest_available_zulu_version "${1}" "${2}")

	if [ "${1}" == "21" ]
	then
		assert_equals "${latest_available_zulu_version}" "21.30.15"
	else
		assert_equals \
			"${latest_available_zulu_version}" \
			$(curl \
				--header 'accept: */*' \
				--location \
				--silent \
				"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?arch=${2}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=${1}&os=linux" | \
				jq -r '.zulu_version | join(".")' | \
				cut -d '.' -f 1,2,3)
	fi
}

function _test_build_all_images_has_slim_build_criteria {
	echo -e "Running _test_build_all_images_has_slim_build_criteria for version ${1}.\n"

	has_slim_build_criteria "${1}"

	assert_equals "${?}" "${2}"
}

main