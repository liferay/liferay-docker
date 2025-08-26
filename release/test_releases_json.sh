#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_releases_json.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_releases_json_add_major_versions
		test_releases_json_get_latest_product_version
		test_releases_json_merge_json_snippets
		test_releases_json_not_process_new_product
		test_releases_json_process_new_product
		test_releases_json_promote_product_versions
		test_releases_json_tag_recommended_product_versions
	fi

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_TEST_MODE="true"
	export _PRODUCT_VERSION="7.4.13-u128"
	export _PROMOTION_DIR="${PWD}"
	export _RELEASE_ROOT_DIR="${PWD}"

	_process_products &> /dev/null
}

function tear_down {
	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_TEST_MODE
	unset _PRODUCT_VERSION
	unset _PROMOTION_DIR
	unset _RELEASE_ROOT_DIR

	rm ./*.json
}

function test_releases_json_add_major_versions {
	_add_major_versions

	assert_equals \
		"$(jq "[.[] | select(.productMajorVersion == \"DXP 2024.Q4\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2024.q4.5")")" \
		"true" \
		"$(jq "[.[] | select(.productMajorVersion == \"DXP 2025.Q1 LTS\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2025.q1.8-lts")")" \
		"true"
}

function test_releases_json_get_latest_product_version {
	_test_releases_json_get_latest_product_version "dxp" "7.3.10-u36"
	_test_releases_json_get_latest_product_version "ga" "7.4.3.132-ga132"
	_test_releases_json_get_latest_product_version "lts" "2025.q1.8-lts"
	_test_releases_json_get_latest_product_version "quarterly" "2025.q2.1"
	_test_releases_json_get_latest_product_version "quarterly-candidate" "2025.q2.1"
}

function test_releases_json_merge_json_snippets {
	local json_files_count=$(
		ls "${_PROMOTION_DIR}" | \
		grep \
			--extended-regexp \
			"(20.*(dxp|portal).*\.json)" 2> /dev/null | \
		wc --lines)

	_merge_json_snippets &> /dev/null

	assert_equals \
		"${json_files_count}" \
		"$(jq length "${_PROMOTION_DIR}/releases.json")"

	rm ./*dxp*.json ./*portal*.json
}

function test_releases_json_not_process_new_product {
	_process_new_product &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function test_releases_json_process_new_product {
	_PRODUCT_VERSION="2024.q4.7"

	_process_products &> /dev/null

	_process_new_product &> /dev/null

	_add_major_versions &> /dev/null

	_promote_product_versions &> /dev/null

	_tag_recommended_product_versions &> /dev/null

	_merge_json_snippets &> /dev/null

	assert_equals \
		"${_PROMOTION_DIR}/releases.json" \
		"${_RELEASE_ROOT_DIR}/test-dependencies/expected/releases.json"
}

function test_releases_json_promote_product_versions {
	_promote_product_versions &> /dev/null

	assert_equals \
		"$(jq "[.[] | select(.promoted == \"true\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2025.q1.8-lts")")" \
		"true"
		"$(jq "[.[] | select(.promoted == \"true\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "7.4.3.132-ga132")")" \
		"true"
}

function test_releases_json_tag_recommended_product_versions {
	_tag_recommended_product_versions &> /dev/null

	assert_equals \
		"$(jq "[.[] | select(.tags[]? == \"recommended\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "$(get_latest_product_version "ga")")")" \
		"true" \
		"$(jq "[.[] | select(.tags[]? == \"recommended\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "$(get_latest_product_version "lts")")")" \
		"true"
}

function _test_releases_json_get_latest_product_version {
	echo -e "Running _test_releases_json_get_latest_product_version for ${1}.\n"

	assert_equals \
		"$(get_latest_product_version "${1}")" \
		"${2}"
}

main "${@}"