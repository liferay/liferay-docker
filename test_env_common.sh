#!/bin/bash

source ./_env_common.sh
source ./_test_common.sh

function main {
	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_env_common_get_environment_type
	fi
}

function test_env_common_get_environment_type {
	_test_env_common_get_environment_type "liferay-123" "local"
	_test_env_common_get_environment_type "release-slave-1" "release_slave"
	_test_env_common_get_environment_type "release-slave-5" ""
	_test_env_common_get_environment_type "test-1-2-3" "ci_slave"
}

function _test_env_common_get_environment_type {
	assert_equals "$(get_environment_type "${1}")" "${2}"
}

main "${@}"