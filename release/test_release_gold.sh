#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source release_gold.sh --test

function main {
	set_up

	test_not_update_release_info_date
	test_update_release_info_date

	tear_down
}

function set_up {
	export _PROJECTS_DIR="${PWD}"/../..

	if [ ! -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist.\n"
	fi
}

function tear_down {
	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	git restore .

	unset _PROJECTS_DIR
}

function test_not_update_release_info_date {
	_test_not_update_release_info_date "2024.q2.11" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "2024.q3.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_not_update_release_info_date "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_update_release_info_date {
	_PRODUCT_VERSION="2024.q2.12"

	update_release_info_date --test 1> /dev/null

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.date")" \
		"$(date -d "next monday" +"%B %-d, %Y")"
}

function _test_not_update_release_info_date {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_not_update_release_info_date for ${_PRODUCT_VERSION}\n"

	update_release_info_date --test 1> /dev/null

	assert_equals "${?}" "${2}"
}

main