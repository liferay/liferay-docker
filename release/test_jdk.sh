#!/bin/bash
source ../_test_common.sh
source ./_jdk.sh

function main {
	set_up

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ "${#}" -eq 1 ]
	then
		"${1}"
	else
		test_jdk_set_jdk_version_and_parameters
	fi

	tear_down
}

function set_up {
	if [ -z "${JAVA_OPTS}" ]
	then
		JAVA_OPTS="-XX:+IgnoreUnrecognizedVMOptions -XX:MaxPermSize=256m -Xmx2048m"
	fi

	export _CURRENT_JAVA_HOME="${JAVA_HOME}"
	export _CURRENT_JAVA_OPTS="${JAVA_OPTS}"
	export _CURRENT_PATH="${PATH}"
	export _JDK_PARAMETERS_17=$(echo "${JAVA_OPTS}" | sed "s/-XX:MaxPermSize=[^ ]*//g")
	export _JDK_PARAMETERS_8="${JAVA_OPTS}"

	export _JDK_VERSION_8="zulu8"

	if [ ! -d "/opt/java/zulu8" ]
	then
		_JDK_VERSION_8="jdk8"
	fi

	export _JDK_VERSION_17="openjdk17"

	if [ ! -d "/opt/java/openjdk17" ]
	then
		_JDK_VERSION_17="jdk17"
	fi

	if [ ! -d "/opt/java/jdk8" ] || [ ! -d "/opt/java/jdk17" ]
	then
		echo -e "JDK 8 and JDK 17 are not installed.\n"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function tear_down {
	JAVA_HOME="${_CURRENT_JAVA_HOME}"
	PATH="${_CURRENT_PATH}"

	unset _CURRENT_JAVA_HOME
	unset _CURRENT_JAVA_OPTS
	unset _CURRENT_PATH
	unset _JDK_PARAMETERS_8
	unset _JDK_PARAMETERS_17
	unset _JDK_VERSION_8
	unset _JDK_VERSION_17
}

function test_jdk_set_jdk_version_and_parameters {
	_test_jdk_set_jdk_version_and_parameters "2024.q2.0" "/opt/java/${_JDK_VERSION_8}" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "2024.q3.0" "/opt/java/${_JDK_VERSION_8}" "${JAVA_OPTS}"
	_test_jdk_set_jdk_version_and_parameters "2025.q1.0" "/opt/java/${_JDK_VERSION_17}" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "7.3.10-u36" "/opt/java/${_JDK_VERSION_8}" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "7.4.13-u131" "/opt/java/${_JDK_VERSION_8}" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "7.4.13-u132" "/opt/java/${_JDK_VERSION_17}" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "7.4.3-ga131" "/opt/java/${_JDK_VERSION_8}" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "7.4.3-ga132" "/opt/java/${_JDK_VERSION_17}" "${_JDK_PARAMETERS_17}"
}

function _test_jdk_set_jdk_version_and_parameters {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_jdk_set_jdk_version_and_parameters for ${_PRODUCT_VERSION}.\n"

	set_jdk_version_and_parameters 1> /dev/null

	assert_equals \
		"${JAVA_HOME}" "${2}" \
		"${JAVA_OPTS}" "${3}"

	JAVA_OPTS="${_CURRENT_JAVA_OPTS}"
}

main "${@}"