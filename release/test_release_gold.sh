#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source release_gold.sh --test

function main {
	set_up

	test_not_reference_new_releases
	test_reference_new_releases

	if [ -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		test_check_usage
		test_not_prepare_next_release_branch
		test_not_update_release_info_date

		export LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH="false"

		test_not_prepare_next_release_branch
		test_not_update_release_info_date

		LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH="true"

		test_not_prepare_next_release_branch
		test_not_update_release_info_date
		test_prepare_next_release_branch
		test_update_release_info_date
	else
		echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist.\n"
	fi

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_RC_BUILD_TIMESTAMP="1695892964"
	export _PROJECTS_DIR="${PWD}"/../..
}

function tear_down {
	lc_cd "${_PROJECTS_DIR}/liferay-docker"

	git restore .

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee" 2> /dev/null

	git restore .

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_RC_BUILD_TIMESTAMP
	unset _PROJECTS_DIR
}

function test_check_usage {
	assert_equals "$(check_usage)" "$(cat test-dependencies/expected/check_usage_output.txt)"
}

function test_not_prepare_next_release_branch {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep -i "true") ]
	then
		_test_not_prepare_next_release_branch "2024.q1.12" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_test_not_prepare_next_release_branch "2023.q2.5" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_prepare_next_release_branch "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_prepare_next_release_branch "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_prepare_next_release_branch "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_not_reference_new_releases {
	_test_not_reference_new_releases "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_reference_new_releases "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_reference_new_releases "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_not_update_release_info_date {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep -i "true") ]
	then
		_test_not_update_release_info_date "2024.q1.12" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_test_not_update_release_info_date "2023.q2.11" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "2023.q3.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_prepare_next_release_branch {
	_PRODUCT_VERSION="2024.q1.12"

	prepare_next_release_branch --test 1> /dev/null

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.display.name[master-private]")" \
		"2024.Q1.13" \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.display.name[release-private]")" \
		"2024.Q1.13"
}

function test_reference_new_releases {
	lc_cd "test-dependencies/actual"

	_PRODUCT_VERSION="2024.q3.13"

	reference_new_releases --test 1> /dev/null

	lc_cd "${_PROJECTS_DIR}/liferay-docker/release"

	assert_equals \
		test-dependencies/actual/build.properties \
		test-dependencies/expected/build.properties
}

function test_update_release_info_date {
	_PRODUCT_VERSION="2024.q2.12"

	update_release_info_date --test 1> /dev/null

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.date")" \
		"$(date -d "next monday" +"%B %-d, %Y")"
}

function _test_not_prepare_next_release_branch {
	_PRODUCT_VERSION="${1}"

	echo -e \
		"Running _test_not_prepare_next_release_branch for ${_PRODUCT_VERSION} " \
		"and LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH=${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}\n"

	prepare_next_release_branch --test 1> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_not_reference_new_releases {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_not_reference_new_releases for ${_PRODUCT_VERSION}\n"

	reference_new_releases --test 1> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_not_update_release_info_date {
	_PRODUCT_VERSION="${1}"

	echo -e \
		"Running _test_not_update_release_info_date for ${_PRODUCT_VERSION} " \
		"and LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH=${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}\n"

	update_release_info_date --test 1> /dev/null

	assert_equals "${?}" "${2}"
}

main