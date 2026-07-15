#!/bin/bash

source ../_test_common.sh
source ./scan_docker_image.sh

function main {
	test_scan_docker_image

	tear_down
}

function tear_down {
	unset LIFERAY_DOCKER_IMAGE_NAME
}

function test_scan_docker_image {
	_test_scan_docker_image "liferay/dxp:7.4.13-u134" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_scan_docker_image "liferay/release-candidates:7.4.13-u134-123456789" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_scan_docker_image "liferay/release-candidates:7.3.10-u36-123456789" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_scan_docker_image "liferay/release-candidates:2025.q1.12-123456789" "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function _test_scan_docker_image {
	LIFERAY_DOCKER_IMAGE_NAME=${1}

	_scan_docker_image &> /dev/null

	assert_equals "${?}" "${2}"
}

main