#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./release_gold.sh --test

function main {
	set_up

	test_release_gold_not_reference_new_releases
	test_release_gold_reference_new_releases

	if [ -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		test_release_gold_check_usage
		test_release_gold_get_tag_name
		test_release_gold_not_prepare_next_release_branch
		test_release_gold_not_update_release_info_date

		export LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH="false"

		test_release_gold_not_prepare_next_release_branch
		test_release_gold_not_update_release_info_date

		LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH="true"

		test_release_gold_not_prepare_next_release_branch
		test_release_gold_not_update_release_info_date
		test_release_gold_prepare_next_release_branch
		test_release_gold_update_release_info_date
	else
		echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist.\n"
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

	git branch --list | grep --extended-regexp 'temp-branch-[0-9]{14}' | xargs -r git branch -D &> /dev/null

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_RC_BUILD_TIMESTAMP
	unset _PROJECTS_DIR
}

function test_release_gold_check_usage {
	assert_equals "$(check_usage)" "$(cat test-dependencies/expected/test_release_gold_check_usage_output.txt)"
}

function test_release_gold_get_tag_name {
	_test_release_gold_get_tag_name "2024.q1.12" "2024.q1.12" "2024.q1.12"
	_test_release_gold_get_tag_name "2025.q1.0" "2025.q1.0-lts" "2025.q1.0"
	_test_release_gold_get_tag_name "7.4.13.u136" "7.4.13-u136" "7.4.13-u136"

	LIFERAY_RELEASE_PRODUCT_NAME="portal"

	_test_release_gold_get_tag_name "7.4.3.132" "7.4.3.132-ga132" "7.4.3.132-ga132"

	LIFERAY_RELEASE_PRODUCT_NAME="dxp"
}

function test_release_gold_not_prepare_next_release_branch {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep --ignore-case "true") ]
	then
		_test_release_gold_not_prepare_next_release_branch "2024.q1.12" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_test_release_gold_not_prepare_next_release_branch "2023.q2.5" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_prepare_next_release_branch "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_prepare_next_release_branch "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_prepare_next_release_branch "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_release_gold_not_reference_new_releases {
	_test_release_gold_not_reference_new_releases "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_reference_new_releases "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_reference_new_releases "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_release_gold_not_update_release_info_date {
	if [ ! $(echo "${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}" | grep --ignore-case "true") ]
	then
		_test_release_gold_not_update_release_info_date "2024.q1.12" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_test_release_gold_not_update_release_info_date "2023.q2.11" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_update_release_info_date "2023.q3.0" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_update_release_info_date "7.3.10-u36" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_update_release_info_date "7.4.13-u101" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_gold_not_update_release_info_date "7.4.3.125-ga125" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_release_gold_prepare_next_release_branch {
	_test_release_gold_prepare_next_release_branch "2024.q1.12" "2024.Q1.13"
	_test_release_gold_prepare_next_release_branch "2025.q1.0" "2025.Q1.1 LTS"
}

function _test_release_gold_get_tag_name {
	_ARTIFACT_VERSION="${1}"
	_PRODUCT_VERSION="${2}"

	echo -e "Running _test_release_gold_get_tag_name for ${3}.\n"

	assert_equals "$(get_tag_name)" "${3}"
}

function _test_release_gold_prepare_next_release_branch {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_release_gold_prepare_next_release_branch for ${_PRODUCT_VERSION}.\n"

	local current_dir="${PWD}"

	prepare_next_release_branch &> /dev/null

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.display.name[master-private]")" \
		"${2}" \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.display.name[release-private]")" \
		"${2}"

	lc_cd "${current_dir}"
}

function test_release_gold_reference_new_releases {
	for product_version in "2024.q3.13" "2025.q1.1-lts" "2025.q2.1"
	do
		_test_release_gold_reference_new_releases "${product_version}"

		git restore "test-dependencies/actual/build.properties"
	done
}

function test_release_gold_update_release_info_date {
	_PRODUCT_VERSION="2024.q2.12"

	update_release_info_date &> /dev/null

	assert_equals \
		"$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.date")" \
		"$(date -d "next monday" +"%B %-d, %Y")"
}

function _test_release_gold_not_prepare_next_release_branch {
	_PRODUCT_VERSION="${1}"

	echo -e \
		"Running _test_release_gold_not_prepare_next_release_branch for ${_PRODUCT_VERSION} " \
		"and LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH=${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}.\n"

	prepare_next_release_branch 1> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_release_gold_not_reference_new_releases {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_release_gold_not_reference_new_releases for ${_PRODUCT_VERSION}.\n"

	reference_new_releases 1> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_release_gold_reference_new_releases {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_release_gold_reference_new_releases for ${_PRODUCT_VERSION}.\n"

	lc_cd "test-dependencies/actual"

	reference_new_releases 1> /dev/null

	lc_cd "${_PROJECTS_DIR}/liferay-docker/release"

	assert_equals \
		"test-dependencies/actual/build.properties" \
		"test-dependencies/expected/test_release_gold_build_$(echo "${_PRODUCT_VERSION}" | tr '.' '_').properties"
}

function _test_release_gold_not_update_release_info_date {
	_PRODUCT_VERSION="${1}"

	echo -e \
		"Running _test_release_gold_not_update_release_info_date for ${_PRODUCT_VERSION} " \
		"and LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH=${LIFERAY_RELEASE_PREPARE_NEXT_RELEASE_BRANCH}.\n"

	update_release_info_date 1> /dev/null

	assert_equals "${?}" "${2}"
}

main