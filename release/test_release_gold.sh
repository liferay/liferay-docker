#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./release_gold.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_release_gold_not_reference_new_releases
		test_release_gold_reference_new_releases

		if [ -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
		then
			test_release_gold_check_usage
			test_release_gold_not_prepare_next_release_branch
			test_release_gold_set_next_release_date
			test_release_gold_set_next_release_version_display_name
		else
			echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist.\n"
		fi
	fi

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_RC_BUILD_TIMESTAMP="1695892964"
	export _PROJECTS_DIR="${PWD}"/../..

	cp test-dependencies/actual/releases.json .
}

function tear_down {
	common_tear_down

	lc_cd "${_PROJECTS_DIR}/liferay-docker"

	git restore .

	rm --force release/releases.json

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee" 2> /dev/null

	git restore .

	git checkout master &> /dev/null

	git branch --list | grep --extended-regexp 'temp-branch-[0-9]{14}' | xargs --no-run-if-empty git branch -D &> /dev/null

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_RC_BUILD_TIMESTAMP
	unset _PROJECTS_DIR
}

function test_release_gold_check_usage {
	assert_equals "$(check_usage)" "$(cat test-dependencies/expected/test_release_gold_check_usage_output.txt)"
}

function test_release_gold_not_prepare_next_release_branch {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep --ignore-case "true") ]
	then
		_test_release_gold_not_prepare_next_release_branch "2024.q1.12" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_test_release_gold_not_prepare_next_release_branch "2024.q2.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_prepare_next_release_branch "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_prepare_next_release_branch "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_prepare_next_release_branch "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_release_gold_not_reference_new_releases {
	_test_release_gold_not_reference_new_releases "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_reference_new_releases "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_reference_new_releases "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_release_gold_reference_new_releases {
	for product_version in "2024.q3.13" "2025.q1.1-lts" "2025.q2.1"
	do
		_test_release_gold_reference_new_releases "${product_version}"

		git restore "test-dependencies/actual/build-shared.properties"
	done
}

function test_release_gold_set_next_release_date {
	LIFERAY_NEXT_RELEASE_DATE="2025-10-11"

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee" 2> /dev/null

	set_next_release_date &> /dev/null

	lc_cd "${_PROJECTS_DIR}/liferay-docker/release"

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.date")" \
		"October 11, 2025"
}

function test_release_gold_set_next_release_version_display_name {
	LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH="true"

	_test_release_gold_set_next_release_version_display_name "2024.q1" "13" "2024.Q1.13"
	_test_release_gold_set_next_release_version_display_name "2025.q1" "2 LTS" "2025.Q1.2 LTS"
}

function _test_release_gold_not_prepare_next_release_branch {
	_PRODUCT_VERSION="${1}"

	prepare_next_release_branch 1> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_release_gold_not_reference_new_releases {
	_PRODUCT_VERSION="${1}"

	reference_new_releases 1> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_release_gold_reference_new_releases {
	_PRODUCT_VERSION="${1}"

	lc_cd "test-dependencies/actual"

	reference_new_releases 1> /dev/null

	lc_cd "${_PROJECTS_DIR}/liferay-docker/release"

	assert_equals \
		"test-dependencies/actual/build-shared.properties" \
		"test-dependencies/expected/test_release_gold_build_shared_$(echo "${_PRODUCT_VERSION}" | tr '.' '_').properties"
}

function _test_release_gold_set_next_release_version_display_name {
	_PRODUCT_VERSION="${1}"

	local current_dir="${PWD}"

	set_next_release_version_display_name "${1}" "${2}" &> /dev/null

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.display.name[master-private]")" \
		"${3}" \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.display.name[release-private]")" \
		"${3}"

	lc_cd "${current_dir}"
}

main "${@}"