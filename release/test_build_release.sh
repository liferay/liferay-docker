#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _product.sh

function main {
	setup

	test_lts_set_product_version
	test_parameterized_set_product_version

	tear_down
}

function setup {
	export _PROJECTS_DIR="/home/me/dev/projects/liferay-docker/release/test-dependencies/actual"
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
}

function tear_down {
	unset _PROJECTS_DIR
	unset LIFERAY_RELEASE_PRODUCT_NAME
}

function test_lts_set_product_version {
	set_product_version 1> /dev/null

	assert_equals \
		"${_PRODUCT_VERSION}" \
		"2025.q1.0-lts"
}

function test_parameterized_set_product_version {

	_test_parameterized_set_product_version "2024.q1.0" "123456789" "2024.q1.0" "2024.q1.0-123456789"
	_test_parameterized_set_product_version "2025.q1.0" "123456789" "2025.q1.0-lts" "2025.q1.0-123456789"
	_test_parameterized_set_product_version "2025.q1.1" "123456789" "2025.q1.1" "2025.q1.1-123456789"
	_test_parameterized_set_product_version "7.3.10-u36" "123456789" "7.3.10-u36" "7.3.10-u36-123456789"

	LIFERAY_RELEASE_PRODUCT_NAME="portal"

	_test_parameterized_set_product_version "7.4.3.129-ga129" "123456789" "7.4.3.129-ga129" "7.4.3.129-123456789"
}

function _test_parameterized_set_product_version {
	set_product_version "${1}" "${2}" 1> /dev/null

	assert_equals \
		"${_PRODUCT_VERSION}" \
		"${3}" \
		"${_ARTIFACT_RC_VERSION}" \
		"${4}"
}

main