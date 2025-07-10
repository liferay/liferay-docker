#!/bin/bash

source ../_test_common.sh

function main {
	set_up

	test_scan_docker_images_with_invalid_image

	tear_down

	test_scan_docker_images_without_parameters
}

function set_up {
	export LIFERAY_IMAGE_NAMES="liferay/dxp:test-image"
	export LIFERAY_PRISMA_CLOUD_ACCESS_KEY="key"
	export LIFERAY_PRISMA_CLOUD_SECRET="secret"
}

function tear_down {
	unset LIFERAY_IMAGE_NAMES
	unset LIFERAY_PRISMA_CLOUD_ACCESS_KEY
	unset LIFERAY_PRISMA_CLOUD_SECRET
}

function test_scan_docker_images_with_invalid_image {
	assert_equals \
		"$(./scan_docker_images.sh | cut --delimiter ' ' --fields 2-)" \
		"[ERROR] Unable to find liferay/dxp:test-image locally."
}

function test_scan_docker_images_without_parameters {
	assert_equals \
		"$(./scan_docker_images.sh)" \
		"$(cat test-dependencies/expected/test_scan_docker_images_without_parameters_output.txt)"
}

main