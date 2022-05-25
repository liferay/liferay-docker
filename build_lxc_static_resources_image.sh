#!/bin/bash

source ./_common.sh

function build_docker_image {
	local base_image_version=$(./release_notes.sh get-version)
	local lxc_static_resources_image_version=0.1.0

	DOCKER_IMAGE_TAGS=()
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/lxc-static-resources:${lxc_static_resources_image_version}-d${base_image_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/lxc-static-resources:${lxc_static_resources_image_version%.*}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/lxc-static-resources")

	if [ "${1}" == "push" ]
	then
		check_docker_buildx

		docker buildx build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_LXC_STATIC_RESOURCES_VERSION="${lxc_static_resources_image_version}" \
			--build-arg LABEL_NAME="Liferay LXC Static Resources" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${base_image_version}" \
			--builder "liferay-buildkit" \
			--platform "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" \
			--push \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	else
		docker build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_LXC_STATIC_RESOURCES_VERSION="${lxc_static_resources_image_version}" \
			--build-arg LABEL_NAME="Liferay LXC Static Resources" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${base_image_version}" \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	fi
}

function main {
	make_temp_directory templates/lxc-static-resources

	log_in_to_docker_hub

	build_docker_image "${1}"

	clean_up_temp_directory
}

main "${@}"