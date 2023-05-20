#!/bin/bash

function add_licensing {
	lcd "/opt/liferay/dev/projects/liferay-release-tool-ee/"

	lcd "$(read_property /opt/liferay/dev/projects/liferay-portal-ee/release.properties "release.tool.dir")"

	ant -Dext.dir=. -Djava.lib.dir="${JAVA_HOME}/jre/lib" -Dportal.dir=/opt/liferay/dev/projects/liferay-portal-ee -Dportal.release.edition.private=true -f build-release-license.xml
}

function compile_dxp {
	if [ -e "${BUILD_DIR}"/built-sha ] && [ $(cat "${BUILD_DIR}"/built-sha) == "${NARWHAL_GIT_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the compile_dxp step."

		return "${SKIPPED}"
	fi

	lcd /opt/liferay/dev/projects/liferay-portal-ee

	ant all

	local exit_code=${?}

	#
	# Workaround until we implement LPS-182849
	#

	lcd "${BUNDLES_DIR}"

	if [ ! -e tomcat ]
	then
		mv tomcat-* tomcat
	fi

	if [ "${exit_code}" -eq 0 ]
	then
		echo "${NARWHAL_GIT_SHA}" > "${BUILD_DIR}"/built-sha
	fi

	return ${exit_code}
}

function get_dxp_version {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	local major=$(read_property release.properties "release.info.version.major")
	local minor=$(read_property release.properties "release.info.version.minor")

	local branch="${major}.${minor}.x"

	if [ "${branch}" == "7.4.x" ]
	then
		branch=master
	fi

	local bug_fix=$(read_property release.properties "release.info.version.bug.fix[${branch}-private]")
	local trivial=$(read_property release.properties "release.info.version.trivial")

	echo "${major}.${minor}.${bug_fix}-u${trivial}"
}

function pre_compile_setup {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	if [ -e "${BUILD_DIR}"/built-sha ] && [ $(cat "${BUILD_DIR}"/built-sha) == "${NARWHAL_GIT_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the pre_compile_setup step."

		return "${SKIPPED}"
	fi

	ant setup-profile-dxp
}