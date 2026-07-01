#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ../test/_test_util.sh
source ./build_premium_support_lts_releases.sh

function main {
	set_up

	test_build_premium_support_lts_releases_process_premium_support_lts_release_branches

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_TEST_DATE="2025-06-01"
	export _RELEASE_ROOT_DIR=${PWD}
}

function tear_down {
	common_tear_down

	unset LIFERAY_RELEASE_TEST_DATE
	unset _RELEASE_ROOT_DIR
}

function test_build_premium_support_lts_releases_process_premium_support_lts_release_branches {
	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		"release-2023.q1"

	LIFERAY_RELEASE_TEST_DATE="2026-06-01"

	add_release_to_test_dependency "2026.q1.9" "test-dependencies/actual/dxp.html"

	add_release_to_test_dependency "2026.q1.9-1234567890" "test-dependencies/actual/release-candidates.html"

	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		""

	git restore test-dependencies/actual/dxp.html test-dependencies/actual/release-candidates.html

	add_release_to_test_dependency "2025.q2.9-1234567890" "test-dependencies/actual/release-candidates.html"

	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		"release-2026.q1"

	git restore test-dependencies/actual/release-candidates.html

	add_release_to_test_dependency "2025.q1.18-lts" "test-dependencies/actual/dxp.html"

	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		"$(echo -e 'release-2025.q1\nrelease-2026.q1')"

	git restore test-dependencies/actual/dxp.html
}

function _test_build_premium_support_lts_releases_process_premium_support_lts_release_branches {
	local triggered_branches=$(_process_premium_support_lts_release_branches 2>/dev/null | grep "^release-")

	assert_equals \
		"${triggered_branches}" "${1}"
}

main "${@}"
