#!/bin/bash

function package_bundle {
	rm -fr "${_BUILD_DIR}/release"

	local root_dir="${_BUILD_DIR}/release/liferay-dxp"

	mkdir -p "${root_dir}"

	cp -a "${_BUNDLES_DIR}"/* "${root_dir}"

	echo "${_GIT_SHA}" > "${root_dir}"/.githash
	echo "${_DXP_VERSION}" > "${root_dir}"/.liferay-version

	touch "${root_dir}"/.liferay-home

	7z a "${_BUILD_DIR}/release/liferay-dxp-tomcat-${_DXP_VERSION}-${_BUILD_TIMESTAMP}.7z" "${root_dir}"
}