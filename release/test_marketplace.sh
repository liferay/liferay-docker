#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_marketplace.sh

function main {
	if [ "${#}" -eq 1 ]
	then
		set_up

		"${1}"

		tear_down
	else
		set_up

		test_marketplace_check_liferay_marketplace_products_compatibility
		test_marketplace_get_latest_product_virtual_settings_file_entry_json_index

		tear_down
	fi
}

function set_up {
	common_set_up

	export _RELEASE_ROOT_DIR="${PWD}"

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

	cp actual/liferaycommerceminium4globalcss.zip  "${marketplace_dir}"

	lc_cd ..
}

function tear_down {
	common_tear_down

	pgrep --full --list-name "${_BUNDLES_DIR}" | awk '{print $1}' | xargs --no-run-if-empty kill -9

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

function test_marketplace_get_latest_product_virtual_settings_file_entry_json_index {
	_test_marketplace_get_latest_product_virtual_settings_file_entry_json_index "2026.Q2" "2"
	_test_marketplace_get_latest_product_virtual_settings_file_entry_json_index "7.4" "2"
	_test_marketplace_get_latest_product_virtual_settings_file_entry_json_index "empty_version" ""
}

function _test_marketplace_get_latest_product_virtual_settings_file_entry_json_index {
	local product_virtual_settings_file_entries=$(cat "${_RELEASE_ROOT_DIR}/test-dependencies/actual/test_marketplace_${1}.json")

	assert_equals \
		"$(_get_latest_product_virtual_settings_file_entry_json_index "${product_virtual_settings_file_entries}")" \
		"${2}"
}

main "${@}"