#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_publishing.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_publishing_get_patcher_product_version_label
		test_publishing_get_patcher_project_version
		test_publishing_get_root_patcher_project_version_name
		test_publishing_update_bundles_yml
	fi

	tear_down
}

function set_up {
	common_set_up

	export _RELEASE_ROOT_DIR="${PWD}"

	export _BASE_DIR="${_RELEASE_ROOT_DIR}/test-dependencies/actual/liferay-docker"
}

function tear_down {
	common_tear_down

	git restore "${_BASE_DIR}/bundles.yml"

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

	_run_update_bundles_yml "2025.q1.1-lts"
	_run_update_bundles_yml "2025.q2.8"
	_run_update_bundles_yml "7.4.13-u130"

	assert_equals \
		"${_RELEASE_ROOT_DIR}/test-dependencies/actual/liferay-docker/bundles.yml" \
		"${_RELEASE_ROOT_DIR}/test-dependencies/expected/test_publishing_bundles.yml"
}

function _run_update_bundles_yml {
	_PRODUCT_VERSION="${1}"

	_update_bundles_yml &> /dev/null
}

function _test_publishing_get_patcher_product_version_label {
	_PRODUCT_VERSION="${1}"

	assert_equals "$(get_patcher_product_version_label)" "${2}"
}

function _test_publishing_get_patcher_project_version {
	_PRODUCT_VERSION="${1}"
	_ARTIFACT_VERSION="${1}"

	assert_equals "$(get_patcher_project_version)" "${2}"
}

function _test_publishing_get_root_patcher_project_version_name {
	_PRODUCT_VERSION="${1}"

	assert_equals "$(get_root_patcher_project_version_name)" "${2}"
}

main "${@}"