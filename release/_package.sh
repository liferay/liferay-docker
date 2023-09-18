#!/bin/bash

function generate_checksum_files {
	lc_cd "${_BUILD_DIR}"/release/

	for file in *
	do
		if [ -f "${file}" ]
		then
			md5sum "${file}" | sed -e "s/ .*//" > "${file}.MD5"
		fi
	done
}

function package_release {
	rm -fr "${_BUILD_DIR}/release"

	local package_dir="${_BUILD_DIR}/release/liferay-dxp"

	mkdir -p "${package_dir}"

	cp -a "${_BUNDLES_DIR}"/* "${package_dir}"

	echo "${_GIT_SHA}" > "${package_dir}"/.githash
	echo "${_DXP_VERSION}" > "${package_dir}"/.liferay-version

	touch "${package_dir}"/.liferay-home

	lc_cd "${_BUILD_DIR}/release"

	7z a "${_BUILD_DIR}/release/liferay-dxp-tomcat-${_DXP_VERSION}-${_BUILD_TIMESTAMP}.7z" liferay-dxp

	tar czf "${_BUILD_DIR}/release/liferay-dxp-tomcat-${_DXP_VERSION}-${_BUILD_TIMESTAMP}.tar.gz" liferay-dxp

	zip -qr "${_BUILD_DIR}/release/liferay-dxp-tomcat-${_DXP_VERSION}-${_BUILD_TIMESTAMP}.zip" liferay-dxp

	lc_cd liferay-dxp

	zip -qr "${_BUILD_DIR}/release/liferay-dxp-osgi-${_DXP_VERSION}-${_BUILD_TIMESTAMP}.zip" osgi

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee/sql

	zip -qr "${_BUILD_DIR}/release/liferay-sql-${_DXP_VERSION}-${_BUILD_TIMESTAMP}.zip" . -i "*.sql"
}