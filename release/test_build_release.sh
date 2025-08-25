#!/bin/bash

source ../_test_common.sh
source ./build_release.sh

function main {
	set_up

	test_build_release_handle_automated_build
	test_build_release_package_release

	tear_down
}

function set_up {
	common_set_up

	LIFERAY_RELEASE_GIT_REF=2025.q1.1 ./build_release.sh --integration-test > /dev/null

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

function test_build_release_package_release {
	assert_equals \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q1.1-lts-*.7z" -type f | wc --lines)" \
		"1" \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q1.1-lts-*.tar.gz" -type f | wc --lines)" \
		"1" \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q1.1-lts-*.zip" -type f | wc --lines)" \
		"1"
}

main