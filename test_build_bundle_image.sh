#!/bin/bash

source ./_test_common.sh
source ./build_bundle_image.sh --test

function main {
	set_up

	test_build_bundle_image_get_latest_tomcat_version
	test_build_bundle_image_set_parent_image

	tear_down
}

function set_up {
	common_set_up

	export TEMP_DIR="${PWD}"
	export _LATEST_TOMCAT_VERSION_TEST=$(curl \
		"https://downloads.apache.org/tomcat/tomcat-9/" \
		--silent \
		| grep --only-matching --perl-regexp "9\.\d+\.\d+" \
		| sort --version-sort \
		| tail --lines=1)
}

function tear_down {
	common_tear_down

	unset TEMP_DIR
	unset _LATEST_TOMCAT_VERSION_TEST
}

function test_build_bundle_image_get_latest_tomcat_version {
	_test_build_bundle_image_get_latest_tomcat_version "9.0.107" "10.1.40" "10.1.40"
	_test_build_bundle_image_get_latest_tomcat_version "9.0.83" "" "${_LATEST_TOMCAT_VERSION_TEST}"
	_test_build_bundle_image_get_latest_tomcat_version "9.0.84" "9.0.9999" "9.0.9999"
	_test_build_bundle_image_get_latest_tomcat_version "9.0.9999" "" "9.0.9999"

	_LATEST_TOMCAT_VERSION_TEST=$(curl \
		"https://downloads.apache.org/tomcat/tomcat-10/" \
		--silent \
		| grep --only-matching --perl-regexp "10\.\d+\.\d+" \
		| sort --version-sort \
		| tail --lines=1)

	_test_build_bundle_image_get_latest_tomcat_version "10.1.40" "" "${_LATEST_TOMCAT_VERSION_TEST}"
	_test_build_bundle_image_get_latest_tomcat_version "10.1.41" "10.1.9999" "10.1.9999"
	_test_build_bundle_image_get_latest_tomcat_version "10.1.9999" "" "10.1.9999"
}

function test_build_bundle_image_set_parent_image {
	_test_build_bundle_image_set_parent_image "2024.q2.0" "jdk11" "jdk11"
	_test_build_bundle_image_set_parent_image "2024.q3.0" "jdk21" "jdk21"
	_test_build_bundle_image_set_parent_image "2025.q1.0" "jdk21" "jdk21"
	_test_build_bundle_image_set_parent_image "7.2.10.8" "jdk11-jdk8" "jdk11-jdk8"
	_test_build_bundle_image_set_parent_image "7.3.10-u36" "jdk11-jdk8" "jdk11-jdk8"
	_test_build_bundle_image_set_parent_image "7.4.13.nightly" "jdk21" "jdk21"
	_test_build_bundle_image_set_parent_image "7.4.13-u124" "jdk11" "jdk11"
	_test_build_bundle_image_set_parent_image "7.4.13-u125" "jdk21" "jdk21"
	_test_build_bundle_image_set_parent_image "7.4.3.120-ga120" "jdk11" "jdk11"
	_test_build_bundle_image_set_parent_image "7.4.3.125-ga125" "jdk21" "jdk21"
}

function _set_dockerfile {
	echo -e "FROM --platform=amd64 liferay/${1}:latest AS liferay-${1}\n" > "${3}"
	echo -e "FROM liferay-${2}\n" >> "${3}"
}

function _test_build_bundle_image_get_latest_tomcat_version {
	echo -e "Running _test_build_bundle_image_get_latest_tomcat_version for Tomcat vesion ${1}.\n"

	echo "app.server.tomcat.version=${2}" > app.server.properties

	assert_equals "$(get_latest_tomcat_version "${1}")" "${3}"
}

function _test_build_bundle_image_set_parent_image {
	LIFERAY_DOCKER_RELEASE_VERSION="${1}"

	echo -e "Running _test_set_parent_image for ${LIFERAY_DOCKER_RELEASE_VERSION}.\n"

	_set_dockerfile "jdk21" "jdk21" "Dockerfile"

	set_parent_image

	_set_dockerfile "${2}" "${3}" "expected.Dockerfile"

	assert_equals Dockerfile expected.Dockerfile

	rm --force Dockerfile
	rm --force expected.Dockerfile
}

main