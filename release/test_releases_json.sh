#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _releases_json.sh

function main {
	set_up

	test_releases_json_merge_json_snippets dxp
	test_releases_json_process_new_product_1
	test_releases_json_process_new_product_2
	test_releases_json_process_product
	test_releases_json_promote_product_versions dxp
	test_releases_json_tag_recommended_product_versions

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _PRODUCT_VERSION="2024.q1.9999"
	export _PROMOTION_DIR="${PWD}"
	export _RELEASE_ROOT_DIR="${PWD}"

	rm -fr "${HOME}/.liferay-common-cache/releases.liferay.com"

	cp test-dependencies/actual/latest-ga-product-version.json "${_PROMOTION_DIR}"

	mv "${_PROMOTION_DIR}/latest-ga-product-version.json" "${_PROMOTION_DIR}/ga-$(_get_latest_product_version "ga").json"

	_process_products &> /dev/null

	_promote_product_versions dxp &> /dev/null

	_tag_recommended_product_versions &> /dev/null

	_merge_json_snippets &> /dev/null

	_process_new_product &> /dev/null
}

function tear_down {
	unset LIFERAY_RELEASE_PRODUCT_NAME
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

function test_releases_json_process_product {
    assert_equals "$(jq '[.[] | select(.targetPlatformVersion == "2025.q1.1")] | length == 1' releases.json)" "true"
}

function test_releases_json_promote_product_versions {
	local product_name=${1}

	while read -r group_version || [ -n "${group_version}" ]
	do
		last_version=$(ls | grep "${product_name}-${group_version}" | tail -n 1 2>/dev/null)

		if [ -n "${last_version}" ]
		then
			assert_equals "$(jq -r '.[] | .promoted' "${last_version}")" "true"
		fi
	done < "${_RELEASE_ROOT_DIR}/supported-${product_name}-versions.txt"
}

function test_releases_json_tag_recommended_product_versions {
	assert_equals \
		"$(jq "[.[] | select(.releaseKey == \"dxp-$(_get_latest_product_version "quarterly")\" and .tags == [\"recommended\"])] | length == 1" releases.json)" \
		"true" \
		"$(jq '[.[] | select(.product == "portal" and .tags == ["recommended"])] | length == 1' releases.json)" \
		"true" \
		"$(jq '[.[] | select(.tags == ["recommended"])] | length == 2' releases.json)" \
		"true"
}

main