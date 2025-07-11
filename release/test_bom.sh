#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_bom.sh

function main {
	set_up

	if [ $? -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	test_bom_generate_pom_release_bom_api_dxp
	test_bom_generate_pom_release_bom_compile_only_dxp
	test_bom_generate_pom_release_bom_distro_dxp
	test_bom_generate_pom_release_bom_dxp
	test_bom_generate_pom_release_bom_third_party_dxp

	LIFERAY_RELEASE_PRODUCT_NAME="portal"
	_BUNDLES_DIR="${_RELEASE_ROOT_DIR}/test-dependencies/liferay-portal"
	_PRODUCT_VERSION="7.4.3.120-ga120"

	_ARTIFACT_RC_VERSION="$(echo "${_PRODUCT_VERSION}" | cut --delimiter '-' --fields 1)-${_BUILD_TIMESTAMP}"

	test_bom_generate_pom_release_bom_api_portal
	test_bom_generate_pom_release_bom_compile_only_portal
	test_bom_generate_pom_release_bom_distro_portal
	test_bom_generate_pom_release_bom_portal
	test_bom_generate_pom_release_bom_third_party_portal

	_PROJECTS_DIR="${PWD}/test-dependencies/actual"

	test_bom_copy_tld

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export _BUILD_TIMESTAMP=12345
	export _PRODUCT_VERSION="2024.q2.6"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _ARTIFACT_RC_VERSION="${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"
	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..
	export _RELEASE_TOOL_DIR="${_RELEASE_ROOT_DIR}"

	if [ ! -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist.\n"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_RELEASE_ROOT_DIR}/test-dependencies"

	lc_download \
		https://releases-cdn.liferay.com/dxp/2024.q2.6/liferay-dxp-tomcat-2024.q2.6-1721635298.zip \
		liferay-dxp-tomcat-2024.q2.6-1721635298.zip 1> /dev/null

	unzip -q liferay-dxp-tomcat-2024.q2.6-1721635298.zip

	export _BUNDLES_DIR="${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp"

	lc_download \
		https://releases-cdn.liferay.com/portal/7.4.3.120-ga120/liferay-portal-tomcat-7.4.3.120-ga120-1718225443.zip \
		liferay-portal-tomcat-7.4.3.120-ga120-1718225443.zip 1> /dev/null

	unzip -q liferay-portal-tomcat-7.4.3.120-ga120-1718225443.zip

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	git reset --hard &> /dev/null

	git clean -dfx &> /dev/null

	git branch --delete "${_PRODUCT_VERSION}" &> /dev/null

	git fetch --no-tags upstream "${_PRODUCT_VERSION}":"${_PRODUCT_VERSION}" &> /dev/null

	git checkout "${_PRODUCT_VERSION}" &> /dev/null

	lc_cd "${_RELEASE_ROOT_DIR}"
}

function tear_down {
	rm --force --recursive "${_BUNDLES_DIR}"
	rm --force --recursive "${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp"
	rm --force "${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp-tomcat-2024.q2.6-1721635298.zip"
	rm --force "${_RELEASE_ROOT_DIR}/test-dependencies/liferay-portal-tomcat-7.4.3.120-ga120-1718225443.zip"

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	git reset --hard &> /dev/null

	git clean -dfx &> /dev/null

	git checkout master &> /dev/null

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset _ARTIFACT_RC_VERSION
	unset _BUILD_TIMESTAMP
	unset _BUNDLES_DIR
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
	unset _RELEASE_ROOT_DIR
	unset _RELEASE_TOOL_DIR
}

function test_bom_copy_tld {
	mkdir --parents "${_RELEASE_ROOT_DIR}"/test-dependencies/actual/META-INF

	copy_tld "${_RELEASE_ROOT_DIR}/test-dependencies/actual/META-INF" "liferay-*.tld" "ratings.tld" 1> /dev/null

	assert_equals \
		"$(ls test-dependencies/actual/META-INF)" \
		"$(ls test-dependencies/expected/META-INF)"
}

function test_bom_generate_pom_release_bom_api_dxp {
	generate_pom_release_api &> /dev/null

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.dxp.release.bom.api.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_api_portal {
	generate_pom_release_api &> /dev/null

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.portal.release.bom.api.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_compile_only_dxp {
	generate_pom_release_bom_compile_only

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.dxp.release.bom.compile.only.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_compile_only_portal {
	generate_pom_release_bom_compile_only

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.portal.release.bom.compile.only.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_distro_dxp {
	generate_pom_release_distro &> /dev/null

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.dxp.release.bom.distro.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_distro_portal {
	generate_pom_release_distro &> /dev/null

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.portal.release.bom.distro.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_dxp {
	generate_pom_release_bom &> /dev/null

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.dxp.release.bom.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_portal {
	generate_pom_release_bom &> /dev/null

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.portal.release.bom.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_third_party_dxp {
	generate_pom_release_bom_compile_only

	generate_pom_release_bom_third_party

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.dxp.release.bom.third.party.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom
	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_ARTIFACT_RC_VERSION}.pom
}

function test_bom_generate_pom_release_bom_third_party_portal {
	generate_pom_release_bom_compile_only

	generate_pom_release_bom_third_party

	assert_equals \
		release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_ARTIFACT_RC_VERSION}.pom \
		test-dependencies/expected/test.bom.portal.release.bom.third.party.pom

	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom
	rm release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_ARTIFACT_RC_VERSION}.pom
}

main