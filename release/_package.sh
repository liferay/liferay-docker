#!/bin/bash

function generate_checksum_files {
	lc_cd "${_BUILD_DIR}"/release

	for file in *
	do
		if [ -f "${file}" ]
		then

			#
			# TODO Remove *.MD5 in favor of *.sha512.
			#

			md5sum "${file}" | sed -e "s/ .*//" > "${file}.MD5"

			sha512sum "${file}" | sed -e "s/ .*//" > "${file}.sha512"
		fi
	done
}

function generate_release_properties_file {
	local tomcat_version=$(grep -Eo "Apache Tomcat Version [0-9]+\.[0-9]+\.[0-9]+" "${_BUNDLES_DIR}/tomcat/RELEASE-NOTES")

	tomcat_version="${tomcat_version/Apache Tomcat Version /}"

	if [ -z "${tomcat_version}" ]
	then
		lc_log DEBUG "Unable to determine the Tomcat version."

		return 1
	fi

	local bundle_file_name="liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z"

	local product_version="DXP ${_PRODUCT_VERSION^^}"

	product_version="${product_version/-/ }"

	(
		echo "app.server.tomcat.version=${tomcat_version}"
		echo "build.timestamp=${_BUILD_TIMESTAMP}"
		echo "bundle.checksum.sha512=$(cat "${bundle_file_name}.sha512")"
		echo "bundle.url=https://releases-cdn.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}/${bundle_file_name}"
		echo "git.hash.liferay-docker=${_BUILDER_SHA}"
		echo "git.hash.liferay-portal-ee=${_GIT_SHA}"
		echo "liferay.docker.image=liferay/${LIFERAY_RELEASE_PRODUCT_NAME}:${_PRODUCT_VERSION}"
		echo "liferay.docker.tags=${_PRODUCT_VERSION}"
		echo "liferay.product.version=${product_version}"
		echo "release.date=$(date +"%Y-%m-%d")"
		echo "target.platform.version=$(echo ${_PRODUCT_VERSION} | sed -r 's/-u/.u/')"
	) > release.properties
}

function install_patching_tool {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_cd "${_BUNDLES_DIR}"

	if [ -e "patching-tool" ]
	then
		lc_log INFO "Patching Tool is already installed."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local latest_version=$(lc_curl https://releases.liferay.com/tools/patching-tool/LATEST-4.0.txt)

	lc_log info "Installing Patching Tool ${latest_version}."

	lc_download https://releases.liferay.com/tools/patching-tool/patching-tool-"${latest_version}".zip patching-tool-"${latest_version}".zip

	unzip -q patching-tool-"${latest_version}".zip

	rm -f patching-tool-"${latest_version}".zip

	lc_cd patching-tool

	./patching-tool.sh auto-discovery

	rm -f logs/*
}

function package_boms {
	lc_cd "${_BUILD_DIR}/boms"

	cp -a ./*.pom "${_BUILD_DIR}/release"

	touch .touch

	jar cvfm "${_BUILD_DIR}/release/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.jar" .touch -C api-jar .
	jar cvfm "${_BUILD_DIR}/release/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}-sources.jar" .touch -C api-sources-jar .

	rm -f .touch
}

function package_release {
	rm -fr "${_BUILD_DIR}/release"

	local package_dir="${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	mkdir -p "${package_dir}"

	cp -a "${_BUNDLES_DIR}"/* "${package_dir}"

	echo "${_GIT_SHA}" > "${package_dir}"/.githash
	echo "${_PRODUCT_VERSION}" > "${package_dir}"/.liferay-version

	touch "${package_dir}"/.liferay-home

	lc_cd "${_BUILD_DIR}/release"

	7z a "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z" liferay-${LIFERAY_RELEASE_PRODUCT_NAME}

	echo "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z" > "${_BUILD_DIR}"/release/.lfrrelease-tomcat-bundle

	tar czf "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.tar.gz" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	lc_cd "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-osgi-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" osgi

	lc_cd tomcat/webapps/ROOT

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.war" ./*

	lc_cd "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tools-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" tools

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	cp -a sql liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql" -i "*.sql"

	rm -fr "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql"

	rm -fr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"
}