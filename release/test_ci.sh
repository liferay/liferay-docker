#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_ci.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_ci_get_test_portal_branch_name
		test_ci_not_trigger_ci_test_suite
	fi

	tear_down
}

function set_up {
	export TRIGGER_CI_TEST_SUITE="false"
}

function tear_down {
	unset TRIGGER_CI_TEST_SUITE
}

function test_ci_get_test_portal_branch_name {
	_test_ci_get_test_portal_branch_name "release-2025.q1" "release-2025.q1"
	_test_ci_get_test_portal_branch_name "release-7.4.13.135" "master"
	_test_ci_get_test_portal_branch_name "release-7.4.3.132-ga132" "master"
}

function test_ci_not_trigger_ci_test_suite {
	trigger_ci_test_suite &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function _test_ci_get_test_portal_branch_name {
	echo -e "Running _test_ci_get_test_portal_branch_name for ${1}.\n"

	assert_equals "$(_get_test_portal_branch_name "${1}")" "${2}"
}

main "${@}"