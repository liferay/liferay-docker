#!/bin/bash

source ../_test_common.sh
source ./_promotion.sh

function main {
	set_up

	test_promotion_prepare_poms_for_promotion

	tear_down
}

function set_up {
	LIFERAY_RELEASE_PRODUCT_NAME="dxp"
	_ARTIFACT_RC_VERSION=2025.q4.2-1765184167
	_ARTIFACT_VERSION=2025.q4.2
	_PROMOTION_DIR="${PWD}/test-dependencies"
}

function tear_down {
	find "${_PROMOTION_DIR}" -maxdepth 1 -type f -regex ".*\.pom.*" -delete
}

function test_promotion_prepare_poms_for_promotion {
	for pom_name in \
		"release.${LIFERAY_RELEASE_PRODUCT_NAME}.api" \
		"release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom" \
		"release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only" \
		"release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.test" \
		"release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party" \
		"release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro"
	do
		touch "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom"
		touch "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom.MD5"
		touch "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom.sha512"
	done

	prepare_poms_for_promotion

	assert_equals \
		"$(ls -1 ${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_VERSION}.pom* | wc --lines)" \
		"3" \
		"$(ls -1 ${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_ARTIFACT_VERSION}.pom* | wc --lines)" \
		"3" \
		"$(ls -1 ${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_VERSION}.pom* | wc --lines)" \
		"3" \
		"$(ls -1 ${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.test-${_ARTIFACT_VERSION}.pom* | wc --lines)" \
		"3" \
		"$(ls -1 ${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_ARTIFACT_VERSION}.pom* | wc --lines)" \
		"3" \
		"$(ls -1 ${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_VERSION}.pom* | wc --lines)" \
		"3"
}

main "${@}"