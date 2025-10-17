#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_bom.sh
source ./_promotion.sh

function main {
	set_up

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_promotion_generate_distro_jar
	fi

	tear_down
}

function set_up {
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_VERSION="2024.q2.6"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _ARTIFACT_RC_VERSION="${LIFERAY_RELEASE_VERSION}"
	export _BUILD_DIR="${_RELEASE_ROOT_DIR}/release-data/build"
	export _BUNDLES_DIR="${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp"
	export _PRODUCT_VERSION="${LIFERAY_RELEASE_VERSION}"
	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..

	lc_cd "${_RELEASE_ROOT_DIR}/test-dependencies"

	lc_download \
		https://releases-cdn.liferay.com/dxp/2024.q2.6/liferay-dxp-tomcat-2024.q2.6-1721635298.zip \
		liferay-dxp-tomcat-2024.q2.6-1721635298.zip 1> /dev/null

	unzip -oq liferay-dxp-tomcat-2024.q2.6-1721635298.zip

	mkdir --parents "${_RELEASE_ROOT_DIR}/release-data/build/boms"
}

function tear_down {
	pgrep --full --list-name "${_BUNDLES_DIR}" | awk '{print $1}' | xargs --no-run-if-empty kill -9

	rm --force --recursive "${_BUNDLES_DIR}"
	rm --force --recursive "${_RELEASE_ROOT_DIR}/release-data/build/boms"
	rm --force "${_RELEASE_ROOT_DIR}/test-dependencies/liferay-dxp-tomcat-2024.q2.6-1721635298.zip"

	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_VERSION
	unset _BUILD_DIR
	unset _BUNDLES_DIR
	unset _PRODUCT_VERSION
	unset _PROJECTS_DIR
	unset _RELEASE_ROOT_DIR
}

function test_promotion_generate_distro_jar {
	generate_distro_jar &> /dev/null

	assert_equals "$(find "${_RELEASE_ROOT_DIR}" -name "release.dxp.distro-${LIFERAY_RELEASE_VERSION}*.jar" | grep --count /)" 1
}

main "${@}"