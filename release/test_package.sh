#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ../_test_common.sh
source ./_package.sh

function main {
	set_up

	test_package_generate_javadocs
	test_package_not_generate_javadocs
	test_package_portal_dependencies

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _BUILD_DIR="${PWD}/test-dependencies"
	export _BUILD_TIMESTAMP="1234567890"
	export _PROJECTS_DIR="${PWD}/test-dependencies/expected"

	common_set_up

	mkdir --parents "${_BUILD_DIR}/release"

	lc_cd test-dependencies

	lc_download \
		https://releases.liferay.com/dxp/7.3.10-u36/liferay-dxp-tomcat-7.3.10-u36-1706652128.zip \
		liferay-dxp-tomcat-7.3.10-u36-1706652128.zip 1> /dev/null

	unzip -q liferay-dxp-tomcat-7.3.10-u36-1706652128.zip -d "${_BUILD_DIR}/release"

	lc_cd ..
}

function tear_down {
	common_tear_down

	rm --force "${_BUILD_DIR}/liferay-dxp-tomcat-7.3.10-u36-1706652128.zip"
	rm --force --recursive "${_BUILD_DIR}/release"

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _BUILD_DIR
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
}

function test_package_generate_javadocs {
	_test_package_generate_javadocs "2025.q3.0"
	_test_package_generate_javadocs "2026.q1.0-lts"
	_test_package_generate_javadocs "7.3.10-ga1"
	_test_package_generate_javadocs "7.3.10-u36"
	_test_package_generate_javadocs "7.4.3.132-ga132"
}

function test_package_not_generate_javadocs {
	_test_package_not_generate_javadocs "2025.q2.0"
	_test_package_not_generate_javadocs "2025.q3.1"
	_test_package_not_generate_javadocs "2026.q1.1-lts"
	_test_package_not_generate_javadocs "7.4.13-u136"
}

function test_package_portal_dependencies {
	_PRODUCT_VERSION="7.3.10-u36"

	lc_cd "${_BUILD_DIR}/release"

	package_portal_dependencies

	unzip -q "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
	unzip -q "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"

	assert_equals \
		"$(ls -1 liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION})" \
		"$(cat ${_BUILD_DIR}/expected/test_publishing_liferay-dxp-client-7.3.10-u36.txt)" \
		"$(ls -1 liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION})" \
		"$(cat ${_BUILD_DIR}/expected/test_publishing_liferay-dxp-dependencies-7.3.10-u36.txt)"

	rm --force "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
	rm --force "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
}

 function _test_package_generate_javadocs {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_package_generate_javadocs for ${_PRODUCT_VERSION}.\n"

	generate_javadocs &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_OK}"
 }

function _test_package_not_generate_javadocs {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_package_not_generate_javadocs for ${_PRODUCT_VERSION}.\n"

	generate_javadocs &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

main