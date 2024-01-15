#!/bin/bash

function add_licensing {
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

function build_dxp {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm -fr "${_BUNDLES_DIR}"

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

	rm -f apache-tomcat*

	mv deploy/*.war osgi/war

	rm -fr osgi/test

	#
	# TODO Remove in 2025
	#

	rm -f tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/mysql.jar

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
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee/modules

	(	
		git grep "Liferay-Releng-Bundle: false" | sed -e s/app.bnd:.*//
		git ls-files "*/.lfrbuild-releng-ignore" | sed -e s#/.lfrbuild-releng-ignore##
	) | while IFS= read -r ignored_dir
	do
		local dxp_dir=""

		if (echo "${ignored_dir}" | grep -Eq "^apps/")
		then
			dxp_dir=$(echo "${ignored_dir}" | sed -e "s#apps/#dxp/apps/#")

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
				rm -f "${_BUNDLES_DIR}/osgi/modules/${ignored_file}.jar"
			elif [ -e "${_BUNDLES_DIR}/osgi/portal/${ignored_file}.jar" ]
			then
				rm -f "${_BUNDLES_DIR}/osgi/portal/${ignored_file}.jar"
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

	rm -fv documentum-hook-*.war
	rm -fv fjord-theme.war
	rm -fv minium-theme.war
	rm -fv opensocial-portlet-*.war
	rm -fv porygon-theme.war
	rm -fv powwow-portlet-*.war
	rm -fv saml-hook-*.war
	rm -fv sharepoint-hook-*.war
	rm -fv social-bookmarks-hook-*.war
	rm -fv speedwell-theme.war
	rm -fv tasks-portlet-*.war
	rm -fv westeros-bank-theme.war
}

function compile_dxp {
	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

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
		if (echo "${bnd_bnd_file}" | grep -q archetype-resources) || (echo "${bnd_bnd_file}" | grep -q modules/third-party)
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

		sed -i -e "s/Bundle-Version: ${bundle_version}/Bundle-Version: ${major_minor_version}.${micro_version}/" "${bnd_bnd_file}"
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

		if ("${_PROJECTS_DIR}"/liferay-portal-ee/gradlew tasks | grep -q deploySidecar)
		then
			"${_PROJECTS_DIR}"/liferay-portal-ee/gradlew deploySidecar
		else
			echo "deploySidecar task does not exist in portal-search-elasticsearch7-impl."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	else
		echo "The directory portal-search-elasticsearch7-impl does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function obfuscate_licensing {
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
		-Dportal.dir="${_PROJECTS_DIR}"/liferay-portal-ee \
		-Dportal.kernel.dir="${_PROJECTS_DIR}"/liferay-portal-ee/portal-kernel \
		-Dportal.release.edition.private=true \
		-f build-release-license.xml obfuscate-portal
}

function set_dxp_version {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	local major_version=$(lc_get_property release.properties "release.info.version.major")
	local minor_version=$(lc_get_property release.properties "release.info.version.minor")

	local branch="${major_version}.${minor_version}.x"

	if [ "${branch}" == "7.4.x" ]
	then
		branch=master
	fi

	local version_display_name=$(lc_get_property release.properties "release.info.version.display.name[${branch}-private]")

	if (echo "${version_display_name}" | grep -iq "q")
	then
		_DXP_VERSION="${version_display_name,,}"
	else
		local bug_fix=$(lc_get_property release.properties "release.info.version.bug.fix[${branch}-private]")
		local trivial=$(lc_get_property release.properties "release.info.version.trivial")

		_DXP_VERSION="${major_version}.${minor_version}.${bug_fix}-u${trivial}"
	fi

	lc_log INFO "DXP Version: ${_DXP_VERSION}"
}

function set_up_profile_dxp {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ant setup-profile-dxp
}

function update_release_info_date {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	sed -i -e "s/release.info.date=.*/release.info.date=$(date +"%B %d, %Y")/" release.properties
}

function warm_up_tomcat {
	if [ -e "${_BUILD_DIR}/warm-up-tomcat" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUNDLES_DIR}/tomcat/bin"

	export LIFERAY_CLEAN_OSGI_STATE=true
	export LIFERAY_JVM_OPTS="-Xmx3G"

	./catalina.sh start

	lc_log INFO "Waiting for Tomcat to start up..."

	for count in {0..30}
	do
		if (curl --fail --output /dev/null --silent http://localhost:8080)
		then
			break
		fi

		sleep 3
	done

	if (! curl --fail --output /dev/null --silent http://localhost:8080)
	then
		lc_log ERROR "Unable to start Tomcat in 90 seconds."

		cat ../logs/catalina.out

		return 1
	fi

	./catalina.sh stop

	local pid=$(lsof -Fp -i 4tcp:8080 -sTCP:LISTEN | head -n 1)

	pid=${pid##p}

	for count in {0..30}
	do
		if (! kill -0 "${pid}" &>/dev/null)
		then
			break
		fi

		sleep 1
	done

	if (kill -0 "${pid}" &>/dev/null)
	then
		lc_log ERROR "Unable to kill Tomcat after 30 seconds."

		cat ../logs/catalina.out

		return 1
	fi

	cat ../logs/catalina.out

	rm -fr ../logs/*
	rm -fr ../../logs/*

	touch "${_BUILD_DIR}/warm-up-tomcat"
}