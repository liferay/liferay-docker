#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _product.sh

function main {
	set_up

	test_get_java_specification_version
	test_lts_set_product_version
	test_parameterized_set_product_version
	test_warm_up_tomcat

	test_warm_up_tomcat_already_warmed

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _BUILD_DIR="${PWD}"
	export _BUNDLES_DIR="${PWD}/test-dependencies/liferay-dxp"
	export _CURRENT_JAVA_HOME="${JAVA_HOME}"
	export _PROJECTS_DIR="/home/me/dev/projects/liferay-docker/release/test-dependencies/actual"

	lc_cd test-dependencies

	lc_download \
		https://releases-cdn.liferay.com/dxp/2024.q2.6/liferay-dxp-tomcat-2024.q2.6-1721635298.zip \
		liferay-dxp-tomcat-2024.q2.6-1721635298.zip 1> /dev/null

	unzip -q liferay-dxp-tomcat-2024.q2.6-1721635298.zip

	lc_cd ..
}

function tear_down {
	rm -f "${_BUILD_DIR}/test-dependencies/liferay-dxp-tomcat-2024.q2.6-1721635298.zip"
	rm -f "${_BUILD_DIR}/warm-up-tomcat"
	rm -fr "${_BUNDLES_DIR}"

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _BUILD_DIR
	unset _BUNDLES_DIR
	unset _CURRENT_JAVA_HOME
	unset _PROJECTS_DIR
}

function test_get_java_specification_version {
	_test_get_java_specification_version "jdk17" "17"
	_test_get_java_specification_version "jdk8" "1.8"
	_test_get_java_specification_version "zulu17" "17"
	_test_get_java_specification_version "zulu8" "1.8"
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

function test_warm_up_tomcat {
	warm_up_tomcat 1> /dev/null

	assert_equals \
		"$(ls -1 ${_BUILD_DIR}/warm-up-tomcat | wc -l)" "1" \
		"$(ls -1 ${_BUNDLES_DIR}/logs | wc -l)" "0" \
		"$(ls -1 ${_BUNDLES_DIR}/tomcat/logs | wc -l)" "0"
}

function test_warm_up_tomcat_already_warmed {
	assert_equals \
		"$(warm_up_tomcat 1> /dev/null; echo "${?}")" \
		"${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
}

function _test_get_java_specification_version {
	JAVA_HOME="/opt/java/${1}"

	echo -e "Running _test_get_java_specification_version for ${JAVA_HOME}\n"

	assert_equals "$(get_java_specification_version)" "${2}"

	JAVA_HOME="${_CURRENT_JAVA_HOME}"
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