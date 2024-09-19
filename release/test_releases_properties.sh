#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _package.sh

function main {
	set_up

	test_generate_release_properties_file_portal

	LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	_PRODUCT_VERSION="7.4.13-u36"

	test_generate_release_properties_file_dxp

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="portal"
	export _BUNDLES_DIR="${PWD}"
	export _PRODUCT_VERSION="7.4.3.120-ga120"

	mkdir -p "${_BUNDLES_DIR}/tomcat"

	echo "Apache Tomcat Version 9.9.99" > "${_BUNDLES_DIR}/tomcat/RELEASE-NOTES"
}

function tear_down {
	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _BUNDLES_DIR
	unset _PRODUCT_VERSION

	rm -f release.properties
	rm -fr tomcat
}

function test_generate_release_properties_file_portal  {
	generate_release_properties_file &>/dev/null

	assert_equals \
		"$(grep 'target.platform.version' release.properties | cut -d '=' -f 2)" \
		"${_PRODUCT_VERSION}"
}

function test_generate_release_properties_file_dxp  {
	generate_release_properties_file &>/dev/null

	assert_equals \
		"$(grep 'target.platform.version' release.properties | cut -d '=' -f 2)" \
		"${_PRODUCT_VERSION/-/.}"
}

main