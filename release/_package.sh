#!/bin/bash

source ../_release_common.sh

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

function generate_javadocs {
	if is_7_4_u_release
	then
		lc_log INFO "Javadocs should not be generated for ${_PRODUCT_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if is_quarterly_release
	then
		if is_early_product_version_than "2025.q3.0" || [[ "$(get_release_patch_version)" -ne 0 ]]
		then
			lc_log INFO "Javadocs should not be generated for ${_PRODUCT_VERSION}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		lc_log INFO "Generating javadocs for ${_PRODUCT_VERSION}."

		git reset --hard && git clean -dfx

		git fetch --no-tags upstream "refs/tags/${_PRODUCT_VERSION}:refs/tags/${_PRODUCT_VERSION}"

		git checkout "tags/${_PRODUCT_VERSION}"

		local portal_release_edition_private="true"

		if is_portal_release
		then
			portal_release_edition_private="false"
		fi

		ant \
			-Ddist.dir="${_BUILD_DIR}/release" \
			-Dliferay.product.name="liferay-${LIFERAY_RELEASE_PRODUCT_NAME}" \
			-Dlp.version="${_PRODUCT_VERSION}" \
			-Dpatch.doc="true" \
			-Dportal.dir="${_PROJECTS_DIR}/liferay-portal-ee" \
			-Dportal.release.edition.private="${portal_release_edition_private}" \
			-Dtstamp.value="${_BUILD_TIMESTAMP}" \
			-f "${_PROJECTS_DIR}/liferay-release-tool-ee/build-service-pack.xml" patch-doc

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to generate javadocs."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi
}

function generate_release_properties_file {
	local tomcat_version=$(grep --extended-regexp --only-matching "Apache Tomcat Version [0-9]+\.[0-9]+\.[0-9]+" "${_BUNDLES_DIR}/tomcat/RELEASE-NOTES")

	tomcat_version="${tomcat_version/Apache Tomcat Version /}"

	if [ -z "${tomcat_version}" ]
	then
		lc_log DEBUG "Unable to determine the Tomcat version."

		return 1
	fi

	local bundle_file_name="liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z"

	local product_version="${_PRODUCT_VERSION^^}"
	local target_platform_version="${_PRODUCT_VERSION}"

	if is_dxp_release
	then
		product_version="DXP ${product_version}"
		target_platform_version=$(echo "${target_platform_version}" | sed -r 's/-u/.u/')

		if is_lts_release
		then
			target_platform_version=$(echo "${target_platform_version}" | sed -r 's/-lts//g')
		fi

	elif is_portal_release
	then
		product_version="Portal ${product_version}"
		target_platform_version=$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 1)
	fi

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
		echo "target.platform.version=${target_platform_version}"
	) > release.properties
}

function install_patching_tool {
	if is_portal_release
	then
		lc_log INFO "Patching Tool should not be installed."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

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

	cp "release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.jar" "${_BUILD_DIR}/release"

	touch .touch

	jar cvfm "${_BUILD_DIR}/release/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.jar" .touch -C api-jar .
	jar cvfm "${_BUILD_DIR}/release/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}-sources.jar" .touch -C api-sources-jar .

	rm -f .touch
}

function package_portal_dependencies {
	if is_7_3_release
	then

		#
		# Client
		#

		rm -fr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}"

		mkdir -p "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}"

		for jar in \
			activation.jar \
			axis.jar \
			commons-discovery.jar \
			commons-logging.jar \
			jaxrpc.jar \
			mail.jar \
			portal-client.jar \
			saaj-api.jar \
			saaj-impl.jar \
			wsdl4j.jar
		do
			local jar_dir="portal"

			if [ "${jar}" == "activation.jar" ] || [ "${jar}" == "mail.jar" ]
			then
				jar_dir="development"
			fi

			cp "${_PROJECTS_DIR}"/liferay-portal-ee/lib/"${jar_dir}"/"${jar}" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}"
		done

		zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}"

		rm -fr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-client-${_PRODUCT_VERSION}"

		#
		# Dependencies
		#

		rm -fr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}"

		mkdir -p "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}"

		for jar in \
			com.liferay.petra.concurrent.jar \
			com.liferay.petra.executor.jar \
			com.liferay.petra.function.jar \
			com.liferay.petra.io.jar \
			com.liferay.petra.lang.jar \
			com.liferay.petra.memory.jar \
			com.liferay.petra.nio.jar \
			com.liferay.petra.process.jar \
			com.liferay.petra.reflect.jar \
			com.liferay.petra.sql.dsl.api.jar \
			com.liferay.petra.sql.dsl.spi.jar \
			com.liferay.petra.string.jar \
			com.liferay.petra.url.pattern.mapper.jar \
			com.liferay.registry.api.jar \
			hsql.jar \
			portal-kernel.jar \
			portlet.jar
		do
			cp "${_BUILD_DIR}"/release/liferay-"${LIFERAY_RELEASE_PRODUCT_NAME}"/tomcat/lib/ext/"${jar}" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}"
		done

		zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}"

		rm -fr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-dependencies-${_PRODUCT_VERSION}"
	fi
}

function package_release {
	if is_portal_release
	then
		rm -fr "${_BUNDLES_DIR}/routes/default/dxp"
	fi

	rm -fr "${_BUILD_DIR}/release"

	local package_dir="${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	mkdir -p "${package_dir}"

	cp -a "${_BUNDLES_DIR}"/* "${package_dir}"

	echo "${_GIT_SHA}" > "${package_dir}"/.githash
	echo "${_PRODUCT_VERSION}" > "${package_dir}"/.liferay-version

	touch "${package_dir}"/.liferay-home

	lc_cd "${_BUILD_DIR}/release"

	package_portal_dependencies

	7z a "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z" liferay-${LIFERAY_RELEASE_PRODUCT_NAME}

	echo "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z" > "${_BUILD_DIR}"/release/.lfrrelease-tomcat-bundle

	tar czf "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.tar.gz" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	lc_cd "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-osgi-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" osgi

	lc_cd tomcat/webapps/ROOT

	if is_7_3_release
	then
		cp "${_PROJECTS_DIR}"/liferay-portal-ee/lib/portal/ccpp.jar WEB-INF/lib
	fi

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.war" ./*

	lc_cd "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-tools-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" tools

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	cp -a sql liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql

	zip -qr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql" -i "*.sql"

	rm -fr "liferay-${LIFERAY_RELEASE_PRODUCT_NAME}-sql"

	rm -fr "${_BUILD_DIR}/release/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}"

	generate_javadocs
}