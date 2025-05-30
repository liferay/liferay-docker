#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_publishing.sh

function main {
	set_up

	test_publishing_get_patcher_product_version_label
	test_publishing_get_patcher_project_version
	test_publishing_get_root_patcher_project_version_name
	test_publishing_update_bundles_yml

	tear_down
}

function set_up {
	common_set_up

	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}/test-dependencies/actual"
}

function tear_down {
	common_tear_down

	git restore "${_PROJECTS_DIR}/liferay-docker/bundles.yml"

	unset _BASE_DIR
	unset _RELEASE_ROOT_DIR
}

function test_publishing_get_patcher_product_version_label {
	_test_publishing_get_patcher_product_version_label "7.3.10-u20" "DXP 7.3"
	_test_publishing_get_patcher_product_version_label "7.4.13-u100" "DXP 7.4"
	_test_publishing_get_patcher_product_version_label "2025.q1.0" "Quarterly Releases"
}

function test_publishing_get_patcher_project_version {
	_test_publishing_get_patcher_project_version "7.3.10-u20" "fix-pack-dxp-20-7310"
	_test_publishing_get_patcher_project_version "7.4.13-u100" "7.4.13-u100"
	_test_publishing_get_patcher_project_version "2025.q1.0" "2025.q1.0"
}

function test_publishing_get_root_patcher_project_version_name {
	_test_publishing_get_root_patcher_project_version_name "7.3.10-u20" "fix-pack-base-7310"
	_test_publishing_get_root_patcher_project_version_name "7.4.13-u100" "7.4.13-ga1"
	_test_publishing_get_root_patcher_project_version_name "2025.q1.0" ""
}

function test_publishing_update_bundles_yml {
	_run_update_bundles_yml "7.4.3.125-ga125"
	_run_update_bundles_yml "7.4.13-u130"
	_run_update_bundles_yml "2024.q3.1"

	assert_equals \
		"${_RELEASE_ROOT_DIR}/test-dependencies/actual/liferay-docker/bundles.yml" \
		"${_RELEASE_ROOT_DIR}/test-dependencies/expected/test_publishing_bundles.yml"
}

function _run_update_bundles_yml {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _update_bundles_yml for ${_PRODUCT_VERSION}.\n"

	_update_bundles_yml &> /dev/null
}

function _test_publishing_get_patcher_product_version_label {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_publishing_get_patcher_product_version_label for ${_PRODUCT_VERSION}.\n"

	assert_equals "$(get_patcher_product_version_label)" "${2}"
}

function _test_publishing_get_patcher_project_version {
	_PRODUCT_VERSION="${1}"
	_ARTIFACT_VERSION="${1}"

	echo -e "Running _test_publishing_get_patcher_project_version for ${_PRODUCT_VERSION}.\n"

	assert_equals "$(get_patcher_project_version)" "${2}"
}

function _test_publishing_get_root_patcher_project_version_name {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_publishing_get_root_patcher_project_version_name for ${_PRODUCT_VERSION}.\n"

	assert_equals "$(get_root_patcher_project_version_name)" "${2}"
}

main