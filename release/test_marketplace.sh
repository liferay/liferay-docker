#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_marketplace.sh

function main {
	trap tear_down EXIT

	set_up

	if [[ "${#}" -eq 1 ]]
	then
		"${1}"
	else
		test_marketplace_check_liferay_marketplace_products_compatibility
		test_marketplace_check_punchout2go_activation_key
		test_marketplace_deploy_punchout2go_activation_key
		test_marketplace_get_cmp_activation_key
		test_marketplace_get_dsr_activation_key
		test_marketplace_get_latest_product_virtual_settings_file_entry_json_index
		test_marketplace_get_liferay_marketplace_product_activation_key_name
		test_marketplace_get_liferay_marketplace_product_module_regex
		test_marketplace_get_liferay_marketplace_product_names
		test_marketplace_not_check_liferay_marketplace_products_compatibility
	fi
}

function set_up {
	common_set_up

	export _RELEASE_ROOT_DIR=${PWD}

	export _BUILD_DIR="${_RELEASE_ROOT_DIR}/release-data/build"
	export _BUNDLES_DIR="${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp"
	export _PRODUCT_VERSION="2025.q3.0"

	lc_cd "${_RELEASE_ROOT_DIR}/test-dependencies"

	lc_download \
		https://releases-cdn.liferay.com/dxp/2025.q3.0/liferay-dxp-tomcat-2025.q3.0-1756231955.zip \
		liferay-dxp-tomcat-2025.q3.0-1756231955.zip 1> /dev/null

	unzip -oq liferay-dxp-tomcat-2025.q3.0-1756231955.zip

	local marketplace_dir="${_BUILD_DIR}/marketplace"

	mkdir --parents "${marketplace_dir}"

	cp actual/liferaycommerceminium4globalcss.zip "${marketplace_dir}"

	lc_cd ..
}

function tear_down {
	common_tear_down

	pgrep --full --list-name "${_BUNDLES_DIR}" | \
		awk '{print $1}' | \
		xargs --no-run-if-empty kill -9

	rm --force --recursive "${_BUILD_DIR}"
	rm --force --recursive "${_BUNDLES_DIR}"
	rm --force "${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp-tomcat-2025.q3.0-1756231955.zip"

	unset _BUILD_DIR
	unset _BUNDLES_DIR
	unset _PRODUCT_VERSION
	unset _RELEASE_ROOT_DIR
}

function test_marketplace_check_liferay_marketplace_products_compatibility {
	declare -A LIFERAY_MARKETPLACE_PRODUCTS=(
		["liferaycommerceminium4globalcss"]="bee3adc0-891c-5828-c4f6-3d244135c972"
	)

	check_liferay_marketplace_products_compatibility &> /dev/null

	assert_equals \
		"${?}" "0" \
		"$(ls -1 "${_BUNDLES_DIR}/osgi/modules/liferaycommerceminium4globalcss.zip" | wc --lines)" "1"
}

function test_marketplace_check_punchout2go_activation_key {
	_test_marketplace_check_punchout2go_activation_key \
		"Liferay Commerce Connector to PunchOut2Go license validation passed" "0"
	_test_marketplace_check_punchout2go_activation_key \
		"Unable to resolve com.liferay.commerce.punchout.api: This application does not have a valid license" "1"
}

function test_marketplace_deploy_punchout2go_activation_key {
	local activation_key_year=$(date +%Y)

	if [[ "$(date +%-m)" -lt 4 ]]
	then
		activation_key_year=$((activation_key_year - 1))
	fi

	local activation_key_directory=$(mktemp --directory)
	local activation_key_file="${activation_key_directory}/activation-key-punchout2go-${activation_key_year}-04-01.xml"

	echo "<license/>" > "${activation_key_file}"

	export "LIFERAY_PUNCHOUT2GO_ACTIVATION_KEY_${activation_key_year}=${activation_key_file}"

	_deploy_punchout2go_activation_key &> /dev/null

	assert_equals \
		"${?}" "0" \
		"$(ls -1 "${_BUNDLES_DIR}/deploy/activation-key-punchout2go-${activation_key_year}-04-01.xml" | wc --lines)" "1"

	rm --force "${_BUNDLES_DIR}/deploy/activation-key-punchout2go-${activation_key_year}-04-01.xml"
	rm --force --recursive "${activation_key_directory}"

	unset "LIFERAY_PUNCHOUT2GO_ACTIVATION_KEY_${activation_key_year}"
}

function test_marketplace_get_cmp_activation_key {
	LIFERAY_CMP_ACTIVATION_KEY_2026="activation-key-cmp-2026.xml"

	_test_marketplace_get_cmp_activation_key "2026" "activation-key-cmp-2026.xml"
	_test_marketplace_get_cmp_activation_key "2027" ""

	unset LIFERAY_CMP_ACTIVATION_KEY_2026
}

function test_marketplace_get_dsr_activation_key {
	LIFERAY_DSR_ACTIVATION_KEY_2026="activation-key-dsr-2026.xml"

	_test_marketplace_get_dsr_activation_key "2026" "activation-key-dsr-2026.xml"
	_test_marketplace_get_dsr_activation_key "2027" ""

	unset LIFERAY_DSR_ACTIVATION_KEY_2026
}

function test_marketplace_get_latest_product_virtual_settings_file_entry_json_index {
	_test_marketplace_get_latest_product_virtual_settings_file_entry_json_index "2026.Q2" "2"
	_test_marketplace_get_latest_product_virtual_settings_file_entry_json_index "7.4" "2"
	_test_marketplace_get_latest_product_virtual_settings_file_entry_json_index "empty_version" ""
}

function test_marketplace_get_liferay_marketplace_product_activation_key_name {
	_test_marketplace_get_liferay_marketplace_product_activation_key_name "cmp" "Content Marketing Platform"
	_test_marketplace_get_liferay_marketplace_product_activation_key_name "drools" ""
	_test_marketplace_get_liferay_marketplace_product_activation_key_name "dsr" "Digital Sales Room"
	_test_marketplace_get_liferay_marketplace_product_activation_key_name "punchout" "Liferay Commerce Connector to PunchOut2Go"
}

function test_marketplace_get_liferay_marketplace_product_module_regex {
	_test_marketplace_get_liferay_marketplace_product_module_regex "cmp" "cmp|content.marketing.platform"
	_test_marketplace_get_liferay_marketplace_product_module_regex "drools" "drools"
	_test_marketplace_get_liferay_marketplace_product_module_regex "dsr" "digital.sales.room|dsr"
}

function test_marketplace_get_liferay_marketplace_product_names {
	declare -A LIFERAY_MARKETPLACE_PRODUCTS=(
		["cmp"]="d85abb01-6c60-addd-0f73-6621612aae72"
		["drools"]="15099181"
		["dsr"]="DSR"
	)

	_test_marketplace_get_liferay_marketplace_product_names "2026.q2.0" "drools"
	_test_marketplace_get_liferay_marketplace_product_names "2026.q3.0" "cmp drools dsr"
	_test_marketplace_get_liferay_marketplace_product_names "2026.q3.8" "cmp dsr"
	_test_marketplace_get_liferay_marketplace_product_names "2026.q4.0-cms-standalone" "cmp"
	_test_marketplace_get_liferay_marketplace_product_names "2027.q1.0-lts" "cmp drools dsr"
	_test_marketplace_get_liferay_marketplace_product_names "2027.q1.1-lts" "cmp dsr"
	_test_marketplace_get_liferay_marketplace_product_names "2027.q1.1-lts-cms-standalone" "cmp"

	unset _PRODUCT_VERSION
}

function test_marketplace_not_check_liferay_marketplace_products_compatibility {
	_test_marketplace_not_check_liferay_marketplace_products_compatibility "2025.q1.20-lts"
	_test_marketplace_not_check_liferay_marketplace_products_compatibility "2026.q2.5"
	_test_marketplace_not_check_liferay_marketplace_products_compatibility "7.4.13-u154"
	_test_marketplace_not_check_liferay_marketplace_products_compatibility "7.4.13-u154-cms-standalone"

	unset _PRODUCT_VERSION
}

function _test_marketplace_check_punchout2go_activation_key {
	local deployment_log_file=$(mktemp)

	export _LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE=${deployment_log_file}

	echo "${1}" > "${deployment_log_file}"

	_check_punchout2go_activation_key &> /dev/null

	assert_equals "${?}" "${2}"

	rm --force "${deployment_log_file}"

	unset _LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE
}

function _test_marketplace_get_cmp_activation_key {
	assert_equals "$(_get_cmp_activation_key "${1}")" "${2}"
}

function _test_marketplace_get_dsr_activation_key {
	assert_equals "$(_get_dsr_activation_key "${1}")" "${2}"
}

function _test_marketplace_get_latest_product_virtual_settings_file_entry_json_index {
	local product_virtual_settings_file_entries=$(cat "${_RELEASE_ROOT_DIR}/test-dependencies/actual/test_marketplace_${1}.json")

	assert_equals \
		"$(_get_latest_product_virtual_settings_file_entry_json_index "${product_virtual_settings_file_entries}")" \
		"${2}"
}

function _test_marketplace_get_liferay_marketplace_product_activation_key_name {
	assert_equals "$(_get_liferay_marketplace_product_activation_key_name "${1}")" "${2}"
}

function _test_marketplace_get_liferay_marketplace_product_module_regex {
	assert_equals "$(_get_liferay_marketplace_product_module_regex "${1}")" "${2}"
}

function _test_marketplace_get_liferay_marketplace_product_names {
	_PRODUCT_VERSION=${1}

	assert_equals "$(_get_liferay_marketplace_product_names | xargs)" "${2}"
}

function _test_marketplace_not_check_liferay_marketplace_products_compatibility {
	_PRODUCT_VERSION=${1}

	check_liferay_marketplace_products_compatibility &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

main "${@}"