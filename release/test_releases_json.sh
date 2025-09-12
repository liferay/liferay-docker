#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ../_test_common.sh
source ./_releases_json.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_releases_json_add_database_schema_versions
		test_releases_json_add_major_versions
		test_releases_json_get_database_schema_versions
		test_releases_json_get_latest_product_version
		test_releases_json_get_liferay_upgrade_folder_version
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

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..

	_process_products &> /dev/null
}

function tear_down {
	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_TEST_MODE
	unset _PRODUCT_VERSION
	unset _PROMOTION_DIR
	unset _RELEASE_ROOT_DIR

	rm ./*.json
	rm ./PortalUpgradeProcessRegistryImpl.java
}

function test_releases_json_add_database_schema_versions {
	_get_portal_upgrade_registry "2025.q2.1"

	_add_database_schema_versions &> /dev/null

	assert_equals \
		"$(jq "[.[] | select(.databaseSchemaVersion == \"32.0.0\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2025.q2.1")")" \
		"true"
}

function test_releases_json_add_major_versions {
	_add_major_versions

	assert_equals \
		"$(jq "[.[] | select(.productMajorVersion == \"DXP 2024.Q4\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2024.q4.5")")" \
		"true" \
		"$(jq "[.[] | select(.productMajorVersion == \"DXP 2025.Q1 LTS\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2025.q1.8-lts")")" \
		"true"
}

function test_releases_json_get_database_schema_versions {
	_test_releases_json_get_database_schema_versions "2024.q2.13" "31.1.0"
	_test_releases_json_get_database_schema_versions "2025.q3.0" "33.3.0"
	_test_releases_json_get_database_schema_versions "7.4.13-u112" "29.2.1"
	_test_releases_json_get_database_schema_versions "7.4.3.132-ga132" "31.14.0"
}

function test_releases_json_get_latest_product_version {
	_test_releases_json_get_latest_product_version "dxp" "7.3.10-u36"
	_test_releases_json_get_latest_product_version "ga" "7.4.3.132-ga132"
	_test_releases_json_get_latest_product_version "lts" "2025.q1.8-lts"
	_test_releases_json_get_latest_product_version "quarterly" "2025.q2.1"
	_test_releases_json_get_latest_product_version "quarterly-candidate" "2025.q2.1"
}

function test_releases_json_get_liferay_upgrade_folder_version {
	_test_releases_json_get_liferay_upgrade_folder_version "2025.q3.0" "v7_4_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.1.10-dxp-28" "v7_1_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.2.10.8" "v7_2_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.3.10-u36" "v7_3_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.4.3.132-ga132" "v7_4_x"
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

function _get_portal_upgrade_registry {
    local current_dir="${PWD}"

    lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

    git fetch upstream tag "${1}" &> /dev/null

    git show \
		"${1}:portal-impl/src/com/liferay/portal/upgrade/v7_4_x/PortalUpgradeProcessRegistryImpl.java" > \
        "${_PROMOTION_DIR}/PortalUpgradeProcessRegistryImpl.java"
    
    git checkout master &> /dev/null

    lc_cd "${current_dir}"
}

function _test_releases_json_get_database_schema_versions {
	_get_portal_upgrade_registry "${1}"

	assert_equals \
		"$(_get_database_schema_version)" \
		"${2}"
}

function _test_releases_json_get_latest_product_version {
	assert_equals \
		"$(get_latest_product_version "${1}")" \
		"${2}"
}

function _test_releases_json_get_liferay_upgrade_folder_version {
	assert_equals \
		"$(_get_liferay_upgrade_folder_version "${1}")" \
		"${2}"
}

main "${@}"