#!/bin/bash

source ../_liferay_common.sh
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
		test_jdk_get_current_jdk_arch
		test_jdk_get_jdk_download_url
		test_jdk_resolve_jdk_install
		test_jdk_set_jdk_version_and_parameters
	fi

	tear_down
}

function set_up {
	common_set_up

	if [ -z "${JAVA_OPTS}" ]
	then
		JAVA_OPTS="-XX:+IgnoreUnrecognizedVMOptions -XX:MaxPermSize=256m -Xmx2048m"
	fi

	export _CURRENT_JAVA_HOME="${JAVA_HOME}"
	export _CURRENT_JAVA_OPTS="${JAVA_OPTS}"
	export _CURRENT_PATH="${PATH}"
	export _JDK_PARAMETERS_17=$(echo "${JAVA_OPTS}" | sed "s/-XX:MaxPermSize=[^ ]*//g")
	export _JDK_PARAMETERS_8="${JAVA_OPTS}"
	export _TEST_JDK_DIR="test-dependencies/test_jdk"

	for jdk_version in open-jdk-17.0.2 zulu-17.0.18+8 zulu8
	do
		mkdir --parents "${_TEST_JDK_DIR}/default_jdk/${jdk_version}"
	done

	mkdir --parents "${_TEST_JDK_DIR}/alternative_jdk/zulu-17.0.18+8"
}

function tear_down {
	JAVA_HOME="${_CURRENT_JAVA_HOME}"
	JAVA_OPTS="${_CURRENT_JAVA_OPTS}"
	PATH="${_CURRENT_PATH}"

	rm --force --recursive "${_TEST_JDK_DIR}"

	unset LIFERAY_RELEASE_TEST_ALTERNATIVE_PATH
	unset LIFERAY_RELEASE_TEST_DEFAULT_PATH
	unset LIFERAY_RELEASE_TEST_MACHINE
	unset LIFERAY_RELEASE_TEST_MODE
	unset _CURRENT_JAVA_HOME
	unset _CURRENT_JAVA_OPTS
	unset _CURRENT_PATH
	unset _JDK_PARAMETERS_17
	unset _JDK_PARAMETERS_8
	unset _TEST_JDK_DIR
}

function test_jdk_get_current_jdk_arch {
	_test_jdk_get_current_jdk_arch "aarch64" "aarch64"
	_test_jdk_get_current_jdk_arch "amd64" "x64"
	_test_jdk_get_current_jdk_arch "arm64" "aarch64"
	_test_jdk_get_current_jdk_arch "x86_64" "x64"
}

function test_jdk_get_jdk_download_url {
	_test_jdk_get_jdk_download_url \
		"aarch64" "open-jdk-17.0.2" \
		"https://download.oracle.com/java/17/archive/jdk-17.0.2_linux-aarch64_bin.tar.gz"
	_test_jdk_get_jdk_download_url \
		"x64" "open-jdk-17.0.2" \
		"https://download.oracle.com/java/17/archive/jdk-17.0.2_linux-x64_bin.tar.gz"
	_test_jdk_get_jdk_download_url \
		"aarch64" "zulu-17.0.18+8" \
		"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?arch=aarch64&bundle_type=jdk&ext=tar.gz&hw_bitness=64&java_version=17.0.18&javafx=false&os=linux"
	_test_jdk_get_jdk_download_url \
		"x64" "zulu-17.0.18+8" \
		"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?arch=x64&bundle_type=jdk&ext=tar.gz&hw_bitness=64&java_version=17.0.18&javafx=false&os=linux"
}

function test_jdk_resolve_jdk_install {
	LIFERAY_RELEASE_TEST_ALTERNATIVE_PATH="${_TEST_JDK_DIR}/alternative_jdk"
	LIFERAY_RELEASE_TEST_DEFAULT_PATH="${_TEST_JDK_DIR}/default_jdk"

	_test_jdk_resolve_jdk_install "open-jdk-17.0.2" "${_TEST_JDK_DIR}/default_jdk/open-jdk-17.0.2"
	_test_jdk_resolve_jdk_install "zulu-17.0.18+8" "${_TEST_JDK_DIR}/default_jdk/zulu-17.0.18+8"
	_test_jdk_resolve_jdk_install "zulu8" "${_TEST_JDK_DIR}/default_jdk/zulu8"

	rm --force --recursive "${_TEST_JDK_DIR}/default_jdk/zulu-17.0.18+8"

	_test_jdk_resolve_jdk_install "zulu-17.0.18+8" "${_TEST_JDK_DIR}/alternative_jdk/zulu-17.0.18+8"

	mkdir "${_TEST_JDK_DIR}/default_jdk/zulu-17.0.18+8"
}

function test_jdk_set_jdk_version_and_parameters {
	LIFERAY_RELEASE_TEST_ALTERNATIVE_PATH="${_TEST_JDK_DIR}/alternative_jdk"
	LIFERAY_RELEASE_TEST_DEFAULT_PATH="${_TEST_JDK_DIR}/default_jdk"

	_test_jdk_set_jdk_version_and_parameters "2024.q1.26-lts" "zulu-17.0.18+8" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2024.q1.27-lts" "zulu-17.0.18+8" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2024.q2.0" "zulu8" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "2024.q3.0" "zulu8" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "2025.q1.0-lts" "open-jdk-17.0.2" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2025.q1.23-lts" "zulu-17.0.18+8" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2025.q1.24-lts" "zulu-17.0.18+8" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2026.q1.3-lts" "open-jdk-17.0.2" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2026.q1.4-lts" "zulu-17.0.18+8" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "2026.q2.0" "zulu-17.0.18+8" "${_JDK_PARAMETERS_17}"
	_test_jdk_set_jdk_version_and_parameters "7.3.10-u36" "zulu8" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "7.4.13-u131" "zulu8" "${_JDK_PARAMETERS_8}"
	_test_jdk_set_jdk_version_and_parameters "7.4.13-u132" "open-jdk-17.0.2" "${_JDK_PARAMETERS_17}"
}

function _test_jdk_get_current_jdk_arch {
	LIFERAY_RELEASE_TEST_MACHINE="${1}"

	assert_equals "$(_get_current_jdk_arch)" "${2}"
}

function _test_jdk_get_jdk_download_url {
	assert_equals "$(_get_jdk_download_url "${1}" "${2}")" "${3}"
}

function _test_jdk_resolve_jdk_install {
	assert_equals "$(_resolve_jdk_install "${1}")" "${2}"
}

function _test_jdk_set_jdk_version_and_parameters {
	_PRODUCT_VERSION="${1}"

	set_jdk_version_and_parameters &> /dev/null

	assert_equals \
		"${JAVA_HOME}" "${LIFERAY_RELEASE_TEST_DEFAULT_PATH}/${2}" \
		"${JAVA_OPTS}" "${3}"

	JAVA_OPTS="${_CURRENT_JAVA_OPTS}"
}

main "${@}"