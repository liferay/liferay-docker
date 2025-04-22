#!/bin/bash

source build_bundle_image.sh --test
source _test_common.sh

function main {
	set_up

	test_build_bundle_image_set_parent_image

	tear_down
}

function set_up {
	export TEMP_DIR="${PWD}"
}

function tear_down {
	unset TEMP_DIR
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

function _test_build_bundle_image_set_parent_image {
	LIFERAY_DOCKER_RELEASE_VERSION="${1}"

	echo -e "Running _test_set_parent_image for ${LIFERAY_DOCKER_RELEASE_VERSION}.\n"

	_set_dockerfile "jdk21" "jdk21" "Dockerfile"

	set_parent_image

	_set_dockerfile "${2}" "${3}" "expected.Dockerfile"

	assert_equals Dockerfile expected.Dockerfile

	rm -f Dockerfile
	rm -f expected.Dockerfile
}

main