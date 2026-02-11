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
		test_releases_json_get_general_availability_date
		test_releases_json_get_liferay_upgrade_folder_version
		test_releases_json_get_supported_product_group_versions
		test_releases_json_merge_json_snippets
		test_releases_json_not_process_new_product
		test_releases_json_process_new_product
		test_releases_json_promote_product_versions
		test_releases_json_tag_jakarta_product_versions
		test_releases_json_tag_recommended_product_versions
	fi

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_TEST_DATE
	export _PRODUCT_VERSION="7.4.13-u128"
	export _PROMOTION_DIR="${PWD}"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..

	mkdir --parents "./test_release_json_dir"

	for file_name in \
		"2020-05-17-dxp-7.1.10.6" \
		"2022-05-17-dxp-7.2.10.6" \
		"2024-05-17-dxp-7.4.10.6" \
		"2025-11-08-dxp-2025.q1.2" \
		"2026-11-08-dxp-2026.q3.5" \
		"2026-12-08-dxp-2026.q4.0"
	do
		touch "./test_release_json_dir/${file_name}.json"
	done

	_process_products &> /dev/null
}

function tear_down {
	common_tear_down

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_TEST_DATE
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
	unset _PROMOTION_DIR
	unset _RELEASE_ROOT_DIR

	rm --force --recursive ./test_release_json_dir
	rm --force ./PortalUpgradeProcessRegistryImpl.java
	rm ./*.json
}

function test_releases_json_add_database_schema_versions {
	_get_portal_upgrade_registry "2025.q2.1"

	_add_database_schema_versions &> /dev/null

	assert_equals \
		"$(jq "[.[] | select(.databaseSchemaVersion == \"32.0.0\")] | length == 1" "$(ls "${_PROMOTION_DIR}" | grep "2025.q2.1")")" \
		"true"

	rm --force "${_PROMOTION_DIR}/PortalUpgradeProcessRegistryImpl.java"
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
	_test_releases_json_get_database_schema_versions "7.0.4-ga5" ""

	_test_releases_json_get_database_schema_versions "2024.q2.13" "31.1.0"
	_test_releases_json_get_database_schema_versions "2025.q3.0" "33.3.0"
	_test_releases_json_get_database_schema_versions "7.4.13-u112" "29.2.1"
	_test_releases_json_get_database_schema_versions "7.4.3.132-ga132" "31.14.0"
}

function test_releases_json_get_general_availability_date {
	_test_releases_json_get_general_availability_date "dxp" "2025.q1.0-lts" "2025-02-19"
	_test_releases_json_get_general_availability_date "dxp" "2025.q1.1-lts" "2025-02-24"
	_test_releases_json_get_general_availability_date "dxp" "7.4.13-u145" "2025-12-20"
	_test_releases_json_get_general_availability_date "dxp" "7.4.13-u146" "2026-02-02"
	_test_releases_json_get_general_availability_date "dxp" "7.4.13-u92" "2023-09-01"
	_test_releases_json_get_general_availability_date "portal" "7.4.3.132-ga132" "2025-02-18"
}

function test_releases_json_get_liferay_upgrade_folder_version {
	_test_releases_json_get_liferay_upgrade_folder_version "2025.q3.0" "v7_4_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.1.10-dxp-28" "v7_1_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.2.10.8" "v7_2_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.3.10-u36" "v7_3_x"
	_test_releases_json_get_liferay_upgrade_folder_version "7.4.3.132-ga132" "v7_4_x"
}

function test_releases_json_get_supported_product_group_versions {
	_PROMOTION_DIR="./test_release_json_dir"

	_test_releases_json_get_supported_product_group_versions "" "2025.q1\n2026.q3\n2026.q4\n2027.q1\n7.2\n7.4"
	_test_releases_json_get_supported_product_group_versions "2022-05-17-dxp-7.2.10.6.json" "2025.q1\n2026.q3\n2026.q4\n2027.q1\n7.4"
	_test_releases_json_get_supported_product_group_versions "2026-12-08-dxp-2026.q4.0.json" "2025.q1\n2026.q3\n2026.q4\n7.4"

	_PROMOTION_DIR="${_RELEASE_ROOT_DIR}"
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

	_sort_all_releases_json_attributes &> /dev/null

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

function test_releases_json_tag_jakarta_product_versions {
	_test_releases_json_tag_jakarta_product_versions "2025.q2" "false"
	_test_releases_json_tag_jakarta_product_versions "2025.q3" "true"
	_test_releases_json_tag_jakarta_product_versions "2026.q1" "true"
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
	if [ "${1}" != "7.0.4-ga5" ]
	then
		_get_portal_upgrade_registry "${1}"
	fi

	assert_equals \
		"$(_get_database_schema_version)" \
		"${2}"
}

function _test_releases_json_get_general_availability_date {
	assert_equals \
		"$(_get_general_availability_date "${1}" "${2}")" \
		"${3}"
}

function _test_releases_json_get_liferay_upgrade_folder_version {
	assert_equals \
		"$(_get_liferay_upgrade_folder_version "${1}")" \
		"${2}"
}

function _test_releases_json_get_supported_product_group_versions {
	rm --force "${_RELEASE_ROOT_DIR}/test_release_json_dir/${1}" 2> /dev/null

	assert_equals \
		"$(_get_supported_product_group_versions)" \
		"$(echo -e "${2}")"
}

function _test_releases_json_tag_jakarta_product_versions {
	local product_group_version="${1}"

	local product_group_version_json=$(echo "${product_group_version}" | tr '.' '-').json

	echo "[{\"productGroupVersion\": \"${product_group_version}\"}]" > "${product_group_version_json}"

	_tag_jakarta_product_versions &> /dev/null

	assert_equals \
		"$(jq -r "(.[0].tags // []) | contains([\"jakarta\"])" "${product_group_version_json}")" \
		"${2}"

	rm --force "${product_group_version_json}"
}

main "${@}"