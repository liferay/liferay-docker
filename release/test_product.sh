#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _product.sh

function main {
	set_up

	test_warm_up_tomcat

	test_warm_up_tomcat_already_warmed

	tear_down
}

function set_up {
	export _BUILD_DIR="${PWD}"
	export _BUNDLES_DIR="${PWD}/test-dependencies/liferay-dxp"

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

	unset _BUILD_DIR
	unset _BUNDLES_DIR
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

main