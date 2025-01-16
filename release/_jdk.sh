#!/bin/bash

source ../_liferay_common.sh

function configure_jdk {
	if (java -version | grep -q 1.8.0_381)
	then
		lc_log INFO "JDK is already at version 1.8.0_381."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_RELEASE_ROOT_DIR}"

	if [ ! -e jdk ]
	then
		lc_log INFO "Installing JDK."

		lc_download https://cdn.azul.com/zulu/bin/zulu8.72.0.17-ca-jdk8.0.382-linux_x64.tar.gz zulu8.72.0.17-ca-jdk8.0.382-linux_x64.tar.gz

		tar -xzf zulu8.72.0.17-ca-jdk8.0.382-linux_x64.tar.gz

		mv zulu8.72.0.17-ca-jdk8.0.382-linux_x64 jdk
	fi

	lc_cd jdk

	export JAVA_HOME=$(pwd)

	export PATH="${JAVA_HOME}/bin:${PATH}"

	if (java -version | grep -q 1.8.0_381)
	then
		lc_log ERROR "Unable to install JDK."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

}

function set_jdk_version {
	local jdk_version=jdk8

	if (echo "${_PRODUCT_VERSION}" | grep -q "q")
	then
		if [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1)" -ge 2025 ]]
		then
			jdk_version=zulu17
		fi
	fi

	if [[ "$(echo "${_PRODUCT_VERSION}" | grep "ga")" ]] &&
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2 | sed 's/ga//g')" -ge 132 ]]
	then
		jdk_version=zulu17
	fi

	if [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 1)" == "7.4.13" ]] &&
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2 | tr -d u)" -ge 132 ]]
	then
		jdk_version=zulu17
	fi

	lc_log INFO "Using JDK ${jdk_version} for release ${_PRODUCT_VERSION}"

	export JAVA_HOME="/opt/java/${jdk_version}"
	export PATH="${JAVA_HOME}/bin:${PATH}"
}