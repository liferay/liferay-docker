#!/bin/bash

source _bom.sh
source _liferay_common.sh
source _test_common.sh

function main {
	set_up

	test_dxp_generate_pom_release_bom_compile_only
	test_dxp_generate_pom_release_bom_third_party

	_PRODUCT_VERSION="7.4.3.120-ga120"
	LIFERAY_RELEASE_PRODUCT_NAME="portal"

	test_portal_generate_pom_release_bom_compile_only
	test_portal_generate_pom_release_bom_third_party

	tear_down
}

function set_up {
	export _BUILD_TIMESTAMP=12345
	export _PRODUCT_VERSION="2024.q2.6"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..

	export _RELEASE_TOOL_DIR="${_RELEASE_ROOT_DIR}"

	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"

	cd "${_PROJECTS_DIR}"/liferay-portal-ee

	git branch --delete "${_PRODUCT_VERSION}" &> /dev/null

	git fetch --no-tags upstream "${_PRODUCT_VERSION}":"${_PRODUCT_VERSION}" &> /dev/null

	git checkout --quiet "${_PRODUCT_VERSION}"

	cd "${_RELEASE_ROOT_DIR}"
}

function tear_down {
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
	unset _RELEASE_ROOT_DIR
	unset _RELEASE_TOOL_DIR

	unset LIFERAY_RELEASE_PRODUCT_NAME
}

function test_dxp_generate_pom_release_bom_third_party {
	generate_pom_release_bom_compile_only

	generate_pom_release_bom_third_party

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.dxp.release.bom.third.party.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

function test_portal_generate_pom_release_bom_third_party {
	generate_pom_release_bom_compile_only

	generate_pom_release_bom_third_party

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.portal.release.bom.third.party.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

function test_dxp_generate_pom_release_bom_compile_only {
	generate_pom_release_bom_compile_only

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.dxp.release.bom.compile.only.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

function test_portal_generate_pom_release_bom_compile_only {
	generate_pom_release_bom_compile_only

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom \
		test-dependencies/expected.portal.release.bom.compile.only.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom
}

main