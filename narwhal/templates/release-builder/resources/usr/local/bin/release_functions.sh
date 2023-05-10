#!/bin/bash

function package_bundle {
	rm -fr "${BUILD_DIR}/release"

	local root_dir="${BUILD_DIR}/release/liferay-dxp-tomcat"

	mkdir -p ${root_dir}

	cp -a "${BUNDLES_DIR}"/* "${root_dir}"

	rm -f "${root_dir}"/apache-tomcat*

	echo "${GIT_SHA}" > "${root_dir}"/.githash
	echo "${DXP_VERSION}" > "${root_dir}"/.liferay-version

	touch "${root_dir}"/.liferay-home

	7z a "${BUILD_DIR}/release/liferay-dxp-tomcat-${DXP_VERSION}-${GIT_SHA_SHORT}.7z" "${root_dir}"
}