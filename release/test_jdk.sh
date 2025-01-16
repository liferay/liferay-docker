#!/bin/bash
source ../_test_common.sh
source _jdk.sh

function main {
	set_up

	test_set_jdk_version

	tear_down
}

function set_up {
	CURRENT_JAVA_HOME="${JAVA_HOME}"
	CURRENT_PATH="${PATH}"
}

function tear_down {
	JAVA_HOME="${CURRENT_JAVA_HOME}"
	PATH="${CURRENT_PATH}"
}

function test_set_jdk_version {
	_test_set_jdk_version "2024.q2.0" "/opt/java/jdk8"
	_test_set_jdk_version "2025.q1.0" "/opt/java/zulu17"
	_test_set_jdk_version "7.3.10-u36" "/opt/java/jdk8"
	_test_set_jdk_version "7.4.3-ga131" "/opt/java/jdk8"
	_test_set_jdk_version "7.4.3-ga132" "/opt/java/zulu17"
	_test_set_jdk_version "7.4.13-u131" "/opt/java/jdk8"
	_test_set_jdk_version "7.4.13-u132" "/opt/java/zulu17"
}

function _test_set_jdk_version {
	_PRODUCT_VERSION="${1}"

	echo -e "Running _test_set_jdk_version for ${_PRODUCT_VERSION}\n"

	set_jdk_version 1> /dev/null

	assert_equals "${JAVA_HOME}" "${2}"
}

main