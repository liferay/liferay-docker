#!/bin/bash

source ../_test_common.sh
source ./build_release.sh

function main {
	set_up

	test_build_release_handle_automated_build

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_GIT_REF="release-test"
	export RUN_SCANCODE_PIPELINE="false"
	export TRIGGER_CI_TEST_SUITE="false"
	export _RELEASE_ROOT_DIR="${PWD}"
}

function tear_down {
	unset LIFERAY_RELEASE_GIT_REF
	unset RUN_SCANCODE_PIPELINE
	unset TRIGGER_CI_TEST_SUITE
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

main