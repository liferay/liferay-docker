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

		if is_equals_or_later_product_version_than "2026.q1.4"
		then
			jdk_version="jdk17"
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

	lc_log INFO "Java release:\n $(cat "${JAVA_HOME}/release")"

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

function _get_current_jdk_arch {
	local machine=$(uname --machine)

	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		machine="${LIFERAY_RELEASE_TEST_MACHINE}"
	fi

	if [ "${machine}" == "aarch64" ] || [ "${machine}" == "arm64" ]
	then
		echo "aarch64"

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	if [ "${machine}" == "amd64" ] || [ "${machine}" == "x86_64" ]
	then
		echo "x64"

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function _get_jdk_download_url {
	local arch="${1}"
	local jdk_version="${2}"

	if [[ "${jdk_version}" == open-jdk-17* ]]
	then
		local java_version=$(echo "${jdk_version}" | sed --regexp-extended "s/^open-jdk-//")

		echo "https://download.oracle.com/java/$(echo "${java_version}" | cut --delimiter='.' --fields=1)/archive/jdk-${java_version}_linux-${arch}_bin.tar.gz"

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	if [[ "${jdk_version}" == zulu-17* ]]
	then
		echo "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?arch=${arch}&bundle_type=jdk&ext=tar.gz&hw_bitness=64&java_version=$(echo "${jdk_version}" | sed --regexp-extended "s/^zulu-//; s/\+.*$//")&javafx=false&os=linux"

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function _resolve_jdk_install {
	local jdk_version="${1}"

	local alternative_path="${HOME}/.liferay/java/${jdk_version}"
	local default_path="/opt/java/${jdk_version}"

	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		alternative_path="${LIFERAY_RELEASE_TEST_ALTERNATIVE_PATH}/${jdk_version}"
		default_path="${LIFERAY_RELEASE_TEST_DEFAULT_PATH}/${jdk_version}"
	fi

	if [ -d "${default_path}" ]
	then
		echo "${default_path}"

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	if [ -d "${alternative_path}" ]
	then
		echo "${alternative_path}"

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}