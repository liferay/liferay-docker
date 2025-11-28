#!/bin/bash

source ../_test_common.sh
source ./build_release.sh

function main {
	set_up

	test_build_release_main_function

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		tear_down

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	test_build_release_bundle_smaller_than_1_gb_300_mb
	test_build_release_handle_automated_build
	test_build_release_package_release

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_GIT_REF="release-test"
	export RUN_SCANCODE_PIPELINE="false"
	export TRIGGER_CI_TEST_SUITE="false"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _RELEASE_PACKAGE="${_RELEASE_ROOT_DIR}/release-data/build/release"
}

function tear_down {
	rm --force --recursive "${_RELEASE_ROOT_DIR}/release-data"

	unset LIFERAY_RELEASE_GIT_REF
	unset RUN_SCANCODE_PIPELINE
	unset TRIGGER_CI_TEST_SUITE
	unset _RELEASE_PACKAGE
	unset _RELEASE_ROOT_DIR
}

function test_build_release_bundle_smaller_than_1_gb_300_mb {
	assert_equals \
		"$(( $(stat --format="%s" "${_RELEASE_PACKAGE}"/liferay-dxp-tomcat-2025.q4.0-*.7z) < 1300000000 ))" \
		"1"
}

function test_build_release_handle_automated_build {
	handle_automated_build &> /dev/null

	assert_equals \
		"${LIFERAY_RELEASE_GIT_REF}" \
		"release-2025.q2" \
		"${RUN_SCANCODE_PIPELINE}" \
		"true" \
		"${TRIGGER_CI_TEST_SUITE}" \
		"true"
}

function test_build_release_main_function {
	LIFERAY_RELEASE_GIT_REF=2025.q4.0 ./build_release.sh --integration-test > /dev/null

	local exit_code="${?}"

	assert_equals "${exit_code}" "0"

	if [ "${exit_code}" -ne 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function test_build_release_package_release {
	assert_equals \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q4.0-*.7z" -type f | wc --lines)" \
		"1" \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q4.0-*.tar.gz" -type f | wc --lines)" \
		"1" \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q4.0-*.zip" -type f | wc --lines)" \
		"1"
}

main