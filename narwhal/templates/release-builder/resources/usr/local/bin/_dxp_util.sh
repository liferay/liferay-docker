#!/bin/bash

function add_licensing {
	lcd "/opt/liferay/dev/projects/liferay-release-tool-ee/"

	lcd "$(read_property /opt/liferay/dev/projects/liferay-portal-ee/release.properties "release.tool.dir")"

	ant -Dext.dir=. -Djava.lib.dir="${JAVA_HOME}/jre/lib" -Dportal.dir=/opt/liferay/dev/projects/liferay-portal-ee -Dportal.release.edition.private=true -f build-release-license.xml
}

function compile_dxp {
	if [ -e "${BUILD_DIR}"/built-sha ] && [ $(cat "${BUILD_DIR}"/built-sha) == "${NARWHAL_GIT_SHA}${NARWHAL_HOTFIX_TESTING_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the compile_dxp step."

		return "${SKIPPED}"
	fi

	rm -fr "${BUNDLES_DIR}"

	lcd /opt/liferay/dev/projects/liferay-portal-ee

	ant deploy

	local exit_code=${?}

	#
	# Workaround until we implement LPS-182849
	#

	lcd "${BUNDLES_DIR}"

	if [ ! -e tomcat ]
	then
		mv tomcat-* tomcat
	fi

	rm -f apache-tomcat*

	if [ "${exit_code}" -eq 0 ]
	then
		echo "${NARWHAL_GIT_SHA}${NARWHAL_HOTFIX_TESTING_SHA}" > "${BUILD_DIR}"/built-sha
	fi

	return ${exit_code}
}

function decrement_module_versions {
	lcd /opt/liferay/dev/projects/liferay-portal-ee/modules

	find apps dxp/apps -name bnd.bnd -type f -print0 | while IFS= read -r -d '' bnd
	do
		local module_path=$(dirname "${bnd}")

		if [ ! -e ".releng/${module_path}/artifact.properties" ]
		then
			continue
		fi

		local bundle_version=$(read_bnd_property "${bnd}" "Bundle-Version")

		local major_minor_version=${bundle_version%.*}
		local micro_version=${bundle_version##*.}

		micro_version=$((micro_version - 1))

		sed -i -e "s/Bundle-Version: ${bundle_version}/Bundle-Version: ${major_minor_version}.${micro_version}/" "${bnd}"
	done
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

function obfuscate_licensing {
	lcd "/opt/liferay/dev/projects/liferay-portal-ee"

	ant clean compile

	lcd "/opt/liferay/dev/projects/liferay-release-tool-ee/"

	lcd "$(read_property /opt/liferay/dev/projects/liferay-portal-ee/release.properties "release.tool.dir")"

	ant -Dext.dir=. -Djava.lib.dir="${JAVA_HOME}/jre/lib" -Dportal.dir=/opt/liferay/dev/projects/liferay-portal-ee -Dportal.kernel.dir=/opt/liferay/dev/projects/liferay-portal-ee/portal-kernel -Dportal.release.edition.private=true -f build-release-license.xml obfuscate-portal
}

function pre_compile_setup {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	if [ -e "${BUILD_DIR}"/built-sha ] && [ $(cat "${BUILD_DIR}"/built-sha) == "${NARWHAL_GIT_SHA}${NARWHAL_HOTFIX_TESTING_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the pre_compile_setup step."

		return "${SKIPPED}"
	fi

	ant setup-profile-dxp
}

function warm_up_tomcat {
	if [ -e "${BUNDLES_DIR}/data/document_library" ]
	then
		echo "The data/document_library directory was already created. Not warming up tomcat."

		return "${SKIPPED}"
	fi

	lcd "${BUNDLES_DIR}/tomcat/bin"

	LIFERAY_JVM_OPTS="-Xmx3G"

	./catalina.sh start

	echo "Waiting for tomcat to start up"

	for count in {0..30}
	do
		if (curl --fail --head --output /dev/null --silent http://localhost:8080)
		then
			break
		fi

		sleep 3
	done

	if (! curl --fail --head --output /dev/null --silent http://localhost:8080)
	then
		echo "Failed to start tomcat in 90 seconds"

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
		echo "Killing tomcat was unsuccessful in 30 seconds"

		exit 1
	fi

	rm -fr ../logs/*
	rm -fr ../../logs/*
}