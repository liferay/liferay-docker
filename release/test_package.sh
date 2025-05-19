#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_package.sh

function main {
	set_up

	test_package_portal_dependencies

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _BUILD_DIR="${PWD}/test-dependencies"
	export _BUILD_TIMESTAMP="1234567890"
	export _PRODUCT_VERSION="7.3.10-u36"
	export _PROJECTS_DIR="${PWD}/test-dependencies/expected"

	mkdir -p "${_BUILD_DIR}/release"

	lc_cd test-dependencies

	lc_download \
		https://releases.liferay.com/dxp/7.3.10-u36/liferay-dxp-tomcat-7.3.10-u36-1706652128.zip \
		liferay-dxp-tomcat-7.3.10-u36-1706652128.zip 1> /dev/null

	unzip -q liferay-dxp-tomcat-7.3.10-u36-1706652128.zip -d "${_BUILD_DIR}/release"

	lc_cd ..
}

function tear_down {
	rm -f "${_BUILD_DIR}/liferay-dxp-tomcat-7.3.10-u36-1706652128.zip"
	rm -fr "${_BUILD_DIR}/release"

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _BUILD_DIR
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
}

function test_package_portal_dependencies {
	lc_cd "${_BUILD_DIR}/release"

	package_portal_dependencies

	unzip -q "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
	unzip -q "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"

	assert_equals \
		"$(ls -1 liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION})" \
		"$(cat ${_BUILD_DIR}/expected/test_publishing_liferay-dxp-client-7.3.10-u36.txt)" \
		"$(ls -1 liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION})" \
		"$(cat ${_BUILD_DIR}/expected/test_publishing_liferay-dxp-dependencies-7.3.10-u36.txt)"

	rm -f "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
	rm -f "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip"
}

main