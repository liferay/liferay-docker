#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh

function set_jdk_version_and_parameters {
	local jdk_version="zulu8"

	if is_quarterly_release
	then
		if [[ "$(get_release_year)" -ge 2025 ]]
		then
			jdk_version="openjdk17"
		fi
	fi

	if is_ga_release
	then
		if [[ "$(get_release_version_trivial)" -ge 132 ]]
		then
			jdk_version="openjdk17"
		fi
	fi

	if [[ "$(get_release_version)" == "7.4.13" ]] &&
	   [[ "$(get_release_version_trivial)" -ge 132 ]]
	then
		jdk_version="openjdk17"
	fi

	if [ ! -d "/opt/java/${jdk_version}" ]
	then
		lc_log INFO "JDK ${jdk_version} is not installed."

		jdk_version=$(echo "${jdk_version}" | sed --regexp-extended "s/(openjdk|zulu)/jdk/g")

		if [ ! -d "/opt/java/${jdk_version}" ]
		then
			lc_log INFO "JDK ${jdk_version} is not installed."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi

	lc_log INFO "Using JDK ${jdk_version} for release ${_PRODUCT_VERSION}."

	export JAVA_HOME="/opt/java/${jdk_version}"

	if [[ "${jdk_version}" == *"8"* ]] && [[ ! "${JAVA_OPTS}" =~ "-XX:MaxPermSize" ]]
	then
		JAVA_OPTS="${JAVA_OPTS} -XX:MaxPermSize=256m"
	fi

	if [[ "${jdk_version}" == *"17"* ]]
	then
		JAVA_OPTS=$(echo "${JAVA_OPTS}" | sed "s/-XX:MaxPermSize=[^ ]*//g")
	fi

	export JAVA_OPTS

	export PATH="${JAVA_HOME}/bin:${PATH}"
}