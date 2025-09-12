#!/bin/bash

source ../_release_common.sh

function add_ckeditor_license {
	if ! is_quarterly_release
	then
		lc_log INFO "The product version is not a quarterly release."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if is_early_product_version_than "2025.q2.0"
	then
		lc_log INFO "The quarterly release is earlier than 2025.q2."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local config_file="${_BUNDLES_DIR}/osgi/configs/com.liferay.frontend.editor.ckeditor.web.internal.configuration.CKEditor5Configuration.config"

	if [ -f "${config_file}" ]
	then
		lc_log INFO "The CKEditor license key already exists in ${config_file}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_log INFO "Adding the CKEditor license key to ${config_file}."

	mkdir --parents "$(dirname "${config_file}")"

	echo "licenseKey=\"${LIFERAY_CKEDITOR_LICENSE_KEY}\"" > "${config_file}"
}

function add_licensing {
	if is_portal_release
	then
		lc_log INFO "The product is set to \"portal.\""

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}/liferay-release-tool-ee"

	echo "liferay-release-tool-ee version:"

	git log -1

	lc_cd "$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.tool.dir")"

	ant \
		-Dext.dir=. \
		-Djava.lib.dir="${JAVA_HOME}/jre/lib" \
		-Dportal.dir="${_PROJECTS_DIR}"/liferay-portal-ee \
		-Dportal.release.edition.private=true \
		-f build-release-license.xml
}

function build_product {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm --force --recursive "${_BUNDLES_DIR}"

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	ant deploy

	ant deploy-portal-license-enterprise-app

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee/modules

	ant build-app-jar-release

	#
	# Workaround until we implement LPS-182849.
	#

	lc_cd "${_BUNDLES_DIR}"

	if [ ! -e tomcat ]
	then
		mv tomcat-* tomcat
	fi

	rm --force apache-tomcat*

	if ls deploy/*.war 1> /dev/null 2>&1
	then
		mv deploy/*.war osgi/war
	fi

	rm --force --recursive osgi/test

	#
	# TODO Remove in 2025
	#

	rm --force tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/mysql.jar

	echo "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" > "${_BUILD_DIR}"/built.sha
}

function build_sql {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee/sql

	if [ -e "create/create-postgresql.sql" ]
	then
		lc_log INFO "SQL files were already built."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ant build-db
}

function clean_up_ignored_dxp_modules {
	if is_portal_release
	then
		lc_log INFO "The product is set to \"portal.\""

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee/modules

	(
		git grep "Liferay-Releng-Bundle: false" | sed --expression "s/app.bnd:.*//"
		git ls-files "*/.lfrbuild-releng-ignore" | sed --expression "s#/.lfrbuild-releng-ignore##"
	) | while IFS= read -r ignored_dir
	do
		local dxp_dir=""

		if (echo "${ignored_dir}" | grep --extended-regexp --quiet "^apps/")
		then
			dxp_dir=$(echo "${ignored_dir}" | sed --expression "s#apps/#dxp/apps/#")

			lc_log INFO "Exclude ${dxp_dir} if it exists."

			if [ ! -e "${dxp_dir}" ]
			then
				dxp_dir=""
			else
				lc_log INFO "Excluding ${dxp_dir} as well based on ${ignored_dir}."
			fi
		fi

		find "${ignored_dir}" "${dxp_dir}" -name bnd.bnd | while IFS= read -r ignored_bnd_bnd_file
		do
			local ignored_file=$(lc_get_property "${ignored_bnd_bnd_file}" Bundle-SymbolicName)

			lc_log INFO "Deleting ignored ${ignored_file}.jar."

			if [ -e "${_BUNDLES_DIR}/osgi/modules/${ignored_file}.jar" ]
			then
				rm --force "${_BUNDLES_DIR}/osgi/modules/${ignored_file}.jar"
			elif [ -e "${_BUNDLES_DIR}/osgi/portal/${ignored_file}.jar" ]
			then
				rm --force "${_BUNDLES_DIR}/osgi/portal/${ignored_file}.jar"
			else
				lc_log INFO "Unable to delete ${ignored_file}.jar."
			fi
		done
	done
}

function clean_up_ignored_dxp_plugins {

	#
	# TODO Some modules are needed for master.
	#

	return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"

	lc_cd "${_BUNDLES_DIR}/osgi/war"

	rm --force --verbose documentum-hook-*.war
	rm --force --verbose fjord-theme.war
	rm --force --verbose minium-theme.war
	rm --force --verbose opensocial-portlet-*.war
	rm --force --verbose porygon-theme.war
	rm --force --verbose powwow-portlet-*.war
	rm --force --verbose saml-hook-*.war
	rm --force --verbose sharepoint-hook-*.war
	rm --force --verbose social-bookmarks-hook-*.war
	rm --force --verbose speedwell-theme.war
	rm --force --verbose tasks-portlet-*.war
	rm --force --verbose westeros-bank-theme.war
}

function compile_product {
	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	echo "baseline.jar.report.level=off" > "build.${USER}.properties"

	ant clean compile
}

function copy_copyright {
	lc_cd "${_BUNDLES_DIR}"

	if [ -e license ]
	then
		lc_log INFO "The license directory already exists."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir license

	cp "${_PROJECTS_DIR}"/liferay-portal-ee/copyright.txt license
	cp "${_PROJECTS_DIR}"/liferay-portal-ee/lib/versions.html license
}

function decrement_module_versions {
	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	find . -name bnd.bnd -type f -print0 | while IFS= read -r -d '' bnd_bnd_file
	do
		if (echo "${bnd_bnd_file}" | grep --quiet archetype-resources) || (echo "${bnd_bnd_file}" | grep --quiet modules/third-party)
		then
			continue
		fi

		local bundle_version=$(lc_get_property "${bnd_bnd_file}" "Bundle-Version")

		local major_minor_version=${bundle_version%.*}

		local micro_version=${bundle_version##*.}

		if ! [[ "${micro_version}" =~ ^[0-9]+$ ]]
		then
		    echo "There is an incorrect version in ${bnd_bnd_file}."

		    continue
		fi

		if [ "${micro_version}" -eq "0" ]
		then
			continue
		fi

		micro_version=$((micro_version - 1))

		sed \
			--expression "s/Bundle-Version: ${bundle_version}/Bundle-Version: ${major_minor_version}.${micro_version}/" \
			--in-place \
			"${bnd_bnd_file}"
	done
}

function deploy_elasticsearch_sidecar {
	if [ -e "${_BUNDLES_DIR}"/elasticsearch-sidecar ]
	then
		lc_log INFO "Elasticsearch sidecar already exists in the bundle."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -e "${_PROJECTS_DIR}"/liferay-portal-ee/modules/apps/portal-search-elasticsearch7/portal-search-elasticsearch7-impl ]
	then
		lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee/modules/apps/portal-search-elasticsearch7/portal-search-elasticsearch7-impl

		if ("${_PROJECTS_DIR}"/liferay-portal-ee/gradlew tasks | grep --quiet deploySidecar)
		then
			"${_PROJECTS_DIR}"/liferay-portal-ee/gradlew deploySidecar
		else
			echo "The Gradle task \"deploySidecar\" does not exist in portal-search-elasticsearch7-impl."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	else
		echo "The directory portal-search-elasticsearch7-impl does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function deploy_opensearch {
	lc_cd "${_BUNDLES_DIR}/osgi/portal"

	if [ -e "com.liferay.portal.search.opensearch2.api.jar" ] &&
	   [ -e "com.liferay.portal.search.opensearch2.impl.jar" ]
	then
		lc_log INFO "The OpenSearch connector is already deployed."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log INFO "Deploying the OpenSearch connector."

		lc_cd "${_PROJECTS_DIR}/liferay-portal-ee/modules/apps/portal-search-opensearch2"

		"${_PROJECTS_DIR}/liferay-portal-ee/gradlew" clean deploy
	fi
}

function get_java_specification_version {
	if (echo "${JAVA_HOME}" | grep --extended-regexp "jdk8|zulu8" &> /dev/null)
	then
		echo "1.8"
	fi

	if (echo "${JAVA_HOME}" | grep --extended-regexp "jdk17|openjdk17" &> /dev/null)
	then
		echo "17"
	fi
}

function obfuscate_licensing {
	if is_portal_release
	then
		lc_log INFO "The product is set to \"portal.\""

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}/liferay-release-tool-ee/$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.tool.dir")"

	ant \
		-Dext.dir=. \
		-Djava.lib.dir="${JAVA_HOME}/jre/lib" \
		-Djava.specification.version="$(get_java_specification_version)" \
		-Dportal.dir="${_PROJECTS_DIR}"/liferay-portal-ee \
		-Dportal.kernel.dir="${_PROJECTS_DIR}"/liferay-portal-ee/portal-kernel \
		-Dportal.release.edition.private=true \
		-f build-release-license.xml obfuscate-portal
}

function set_artifact_versions {
	_ARTIFACT_VERSION="${1}"

	if is_dxp_release
	then
		if is_u_release
		then
			_ARTIFACT_VERSION=$(echo "${_ARTIFACT_VERSION}" | tr '-' '.')
		fi
	
		if is_quarterly_release
		then
			_ARTIFACT_VERSION=$(echo "${_ARTIFACT_VERSION}" | sed "s/-lts//g")
		fi
	elif is_portal_release
	then
		_ARTIFACT_VERSION=$(echo "${_ARTIFACT_VERSION}" | sed "s/-ga[0-9]*//g")
	fi

	_ARTIFACT_RC_VERSION="${_ARTIFACT_VERSION}-${2}"
}

function set_product_version {
	if [ "${#@}" -eq 0 ]
	then
		lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

		local major_version=$(lc_get_property release.properties "release.info.version.major")
		local minor_version=$(lc_get_property release.properties "release.info.version.minor")

		local branch="${major_version}.${minor_version}.x"

		if [ "${branch}" == "7.4.x" ]
		then
			branch=master
		fi

		local version_display_name=$(lc_get_property release.properties "release.info.version.display.name[${branch}-private]")

		if (echo "${version_display_name}" | grep --ignore-case --quiet "q")
		then
			_PRODUCT_VERSION=$(echo "${version_display_name,,}" | sed "s/ lts/-lts/g")
		else
			local trivial=$(lc_get_property release.properties "release.info.version.trivial")

			if is_dxp_release
			then
				local bug_fix=$(lc_get_property release.properties "release.info.version.bug.fix[${branch}-private]")

				_PRODUCT_VERSION="${major_version}.${minor_version}.${bug_fix}-u${trivial}"
			elif is_portal_release
			then
				local bug_fix=$(lc_get_property release.properties "release.info.version.bug.fix")

				_PRODUCT_VERSION="${major_version}.${minor_version}.${bug_fix}.${trivial}-ga${trivial}"
			fi
		fi
	else
		_PRODUCT_VERSION="${1}"

		if [[ "$(get_release_year)" -gt 2024 ]] && [[ "$(get_release_quarter)" -eq 1 ]]
		then
			if ! is_lts_release
			then
				_PRODUCT_VERSION="${_PRODUCT_VERSION}-lts"
			fi
		fi

		set_artifact_versions "${_PRODUCT_VERSION}" "${2}"
	fi

	lc_log INFO "Product Version: ${_PRODUCT_VERSION}"
}

function set_up_profile {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ant "setup-profile-${LIFERAY_RELEASE_PRODUCT_NAME}"
}

function start_tomcat {
	export LIFERAY_JVM_OPTS="-Xmx3G"

	rm --force --recursive "${_BUNDLES_DIR}/osgi/state"
	rm --force --recursive "${_BUNDLES_DIR}/tomcat/temp"
	rm --force --recursive "${_BUNDLES_DIR}/tomcat/work"

	lc_cd "${_BUNDLES_DIR}/tomcat/bin"

	./catalina.sh start

	lc_log INFO "Waiting for Tomcat to start up..."

	for count in {0..30}
	do
		if (curl --fail --max-time 3 --output /dev/null --silent http://localhost:8080)
		then
			lc_log INFO "Startup was successful."

			break
		fi

		sleep 3
	done

	if (! curl --fail --max-time 3 --output /dev/null --silent http://localhost:8080)
	then
		lc_log ERROR "Unable to start Tomcat in 90 seconds."

		cat ../logs/catalina.out

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if (echo "${_PRODUCT_VERSION}" | grep --extended-regexp --quiet "^7.[0123]")
	then
		lc_log INFO "Sleep for 20 seconds before shutting down."

		sleep 20
	fi
}

function stop_tomcat {
	lc_cd "${_BUNDLES_DIR}/tomcat/bin"

	lc_log INFO "Stopping Tomcat."

	./catalina.sh stop

	local backslash_and_slash_regex="\\\\\/"
	local slash_regex="\/"

	local tomcat_dir_regex=$(\
		echo "${_BUNDLES_DIR}/tomcat" | \
		sed --expression "s/${slash_regex}/${backslash_and_slash_regex}/g")

	for count in {0..30}
	do
		if (! pkill -0 --full "${tomcat_dir_regex}" &> /dev/null)
		then
			break
		fi

		sleep 1
	done

	if (pkill -0 --full "${tomcat_dir_regex}" &> /dev/null)
	then
		lc_log ERROR "Unable to kill Tomcat after 30 seconds."

		cat ../logs/catalina.out

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	cat ../logs/catalina.out

	rm --force --recursive ../logs/*
	rm --force --recursive ../../logs/*
}

function update_release_info_date {
	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	sed \
		--expression "s/release.info.date=.*/release.info.date=$(date +"%B %d, %Y")/" \
		--in-place \
		release.properties
}

function warm_up_tomcat {
	if [ -e "${_BUILD_DIR}/warm-up-tomcat" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	export LIFERAY_CLEAN_OSGI_STATE=true

	start_tomcat

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	stop_tomcat

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	touch "${_BUILD_DIR}/warm-up-tomcat"
}