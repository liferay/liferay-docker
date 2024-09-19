#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _releases_json.sh

function main {
	set_up

	test_merge_json_snippets dxp
	test_process_new_product
	test_promote_product_versions dxp

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _PRODUCT_VERSION="2024.q1.9999"
	export _PROMOTION_DIR="${PWD}"
	export _RELEASE_ROOT_DIR="${PWD}"

	_process_product dxp &> /dev/null

	_promote_product_versions dxp &> /dev/null

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

function test_merge_json_snippets {
	local earliest_url="$(jq -r '.[0].url' < "$(find ./20*dxp*.json | head -n 1)")"

	local earliest_count="$(grep -c "${earliest_url}" releases.json)"

	local latest_url="$(jq -r '.[0].url' < "$(find ./20*dxp*.json | tail -n 1)")"

	local latest_count="$(grep -c "${latest_url}" releases.json)"

	assert_equals "${earliest_count}" 1 "${latest_count}" 1
}

function test_process_new_product {
	local actual_number_of_promoted_versions=$(jq "map(select(.promoted == \"true\")) | length" 0000-00-00-releases.json)
	local expected_promoted_versions_dxp=$(grep -c '' "${_RELEASE_ROOT_DIR}/supported-dxp-versions.txt")
	local expected_promoted_versions_portal=$(grep -c '' "${_RELEASE_ROOT_DIR}/supported-portal-versions.txt")

	assert_equals "${actual_number_of_promoted_versions}" $((expected_promoted_versions_dxp + expected_promoted_versions_portal - 1))
}

function test_promote_product_versions {
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

main