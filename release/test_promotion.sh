#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _promotion.sh

function main {
	set_up

	prepare_jars_for_promotion xanadu
	prepare_poms_for_promotion xanadu

	test_prepare_resources_for_promotion

	tear_down
}

function set_up {
	export LIFERAY_COMMON_EXIT_CODE_BAD=1
	export LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	export LIFERAY_RELEASE_RC_BUILD_TIMESTAMP="1721635298"
	export LIFERAY_RELEASE_VERSION="2024.q2.6"

	export _PRODUCT_VERSION="${LIFERAY_RELEASE_VERSION}"

	export _ARTIFACT_RC_VERSION="${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}"

	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"
}

function tear_down {
	lc_cd ..

	rm -fr "${_PROMOTION_DIR}"

	unset LIFERAY_COMMON_EXIT_CODE_BAD
	unset LIFERAY_RELEASE_PRODUCT_NAME
	unset LIFERAY_RELEASE_RC_BUILD_TIMESTAMP
	unset LIFERAY_RELEASE_VERSION
	unset _ARTIFACT_RC_VERSION
	unset _PRODUCT_VERSION
	unset _PROMOTION_DIR
	unset _RELEASE_ROOT_DIR
}

function test_prepare_resources_for_promotion {
	assert_equals \
		"$(find "${_PROMOTION_DIR}" -name "release.dxp.distro-${LIFERAY_RELEASE_VERSION}.jar" | grep -c /)" 1 \
		"$(find "${_PROMOTION_DIR}" -name "release.dxp.distro-${LIFERAY_RELEASE_VERSION}.pom" | grep -c /)" 1
}

main