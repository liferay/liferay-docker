#!/bin/bash

source ./_release_common.sh
source ./_test_common.sh

function main {
	test_release_common_is_early_product_version_than
	test_release_common_is_quarterly_release

	unset ACTUAL_PRODUCT_VERSION
}

function test_release_common_is_early_product_version_than {
	_test_release_common_is_early_product_version_than "2023.q3.3" "2025.q2.0" "0"
	_test_release_common_is_early_product_version_than "2024.q4.7" "2025.q1.0" "0"
	_test_release_common_is_early_product_version_than "2025.q1.0" "2025.q1.1" "0"
	_test_release_common_is_early_product_version_than "2025.q1.1-lts" "2025.q1.0-lts" "1"
}

function test_release_common_is_quarterly_release {
	_test_release_common_is_quarterly_release "2025.q1.0-lts" "${LIFERAY_COMMON_EXIT_CODE_OK}"
	_test_release_common_is_quarterly_release "7.4.3.112-ga112" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_release_common_is_quarterly_release "7.4.13-u134" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function _test_release_common_is_early_product_version_than {
	set_actual_product_version "${1}" 

	echo -e "Running _test_release_common_is_early_product_version_than for ${1}.\n"

	assert_equals "$(is_early_product_version_than "${2}")" "${3}"
}

function _test_release_common_is_quarterly_release {
	echo -e "Running _test_release_common_is_quarterly_release for ${1}.\n"

	assert_equals "$(is_quarterly_release "${1}")" "${2}"
}

main