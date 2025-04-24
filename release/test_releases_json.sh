#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _releases_json.sh

function main {
	set_up

	test_releases_json_promote_product_versions
	test_releases_json_tag_recommended_product_versions

	test_releases_json_merge_json_snippets
	test_releases_json_process_new_product_1
	test_releases_json_process_new_product_2

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_TEST_MODE="true"
	export _PRODUCT_VERSION="2024.q1.9999"
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

function test_releases_json_merge_json_snippets {
	local earliest_url="$(jq -r '.[0].url' < "$(find ./20*dxp*.json | head -n 1)")"

	local earliest_count="$(grep -c "\"url\": \"${earliest_url}"\" releases.json)"

	local latest_url="$(jq -r '.[0].url' < "$(find ./20*dxp*.json | tail -n 1)")"

	local latest_count="$(grep -c "\"url\": \"${latest_url}"\" releases.json)"

	assert_equals "${earliest_count}" 1 "${latest_count}" 1
}

function test_releases_json_process_new_product_1 {
	local actual_number_of_promoted_versions=$(jq "map(select(.promoted == \"true\")) | length" 0000-00-00-releases.json)
	local expected_promoted_versions_dxp=$(grep -c '' "${_RELEASE_ROOT_DIR}/supported-dxp-versions.txt")
	local expected_promoted_versions_portal=$(grep -c '' "${_RELEASE_ROOT_DIR}/supported-portal-versions.txt")

	assert_equals "${actual_number_of_promoted_versions}" $((expected_promoted_versions_dxp + expected_promoted_versions_portal - 1))
}

function test_releases_json_process_new_product_2 {
	local temp_product_version=${_PRODUCT_VERSION}

	_PRODUCT_VERSION="7.4.13-u128"

	_process_new_product &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"

	_PRODUCT_VERSION="${temp_product_version}"
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
		"$(jq "[.[] | select(.tags[]? == \"recommended\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "$(_get_latest_product_version "ga")")")" \
		"true" \
		"$(jq "[.[] | select(.tags[]? == \"recommended\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "$(_get_latest_product_version "quarterly")")")" \
		"true"
}

main