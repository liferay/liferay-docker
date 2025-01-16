#!/bin/bash

source ../_liferay_common.sh

function set_jdk_version {
	local jdk_version="zulu8"

	if (echo "${_PRODUCT_VERSION}" | grep -q "q")
	then
		if [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1)" -ge 2025 ]]
		then
			jdk_version="zulu17"
		fi
	fi

	if [[ "$(echo "${_PRODUCT_VERSION}" | grep "ga")" ]] &&
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2 | sed "s/ga//g")" -ge 132 ]]
	then
		jdk_version="zulu17"
	fi

	if [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 1)" == "7.4.13" ]] &&
	   [[ "$(echo "${_PRODUCT_VERSION}" | cut -d '-' -f 2 | tr -d u)" -ge 132 ]]
	then
		jdk_version="zulu17"
	fi

	if [ ! -d "/opt/java/${jdk_version}" ]
	then
		lc_log WARN "JDK ${jdk_version} is not installed"

		jdk_version=$(echo "${jdk_version}" | sed "s/zulu/jdk/g")

		if [ ! -d "/opt/java/${jdk_version}" ]
		then
			lc_log ERROR "JDK ${jdk_version} is not installed"

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi

	lc_log INFO "Using JDK ${jdk_version} for release ${_PRODUCT_VERSION}"

	export JAVA_HOME="/opt/java/${jdk_version}"
	export PATH="${JAVA_HOME}/bin:${PATH}"
}