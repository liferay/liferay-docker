#!/bin/bash

source ./_common.sh

function build_image {
	local connector_image_version=0.1.0

	local base_image_version=$(./release_notes.sh get-version)

	DOCKER_IMAGE_TAGS=()
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/connector:${connector_image_version}-d${base_image_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/connector:${connector_image_version%.*}")

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="Liferay Connector image" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
		--build-arg LABEL_VERSION="${connector_image_version}" \
		$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
		"${TEMP_DIR}"
}

function main {
	make_temp_directory templates/connector

	build_image
}

main