#!/bin/bash

source ./_common.sh

function build_docker_image {
	local image_version=$(./release_notes.sh get-version)

	DOCKER_IMAGE_TAGS=()
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/jdk11:${image_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/jdk11")

	if [ "${1}" == "push" ]
	then
		check_docker_buildx

		docker buildx build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_NAME="Liferay JDK11" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${image_version}" \
			--build-arg LABEL_ZULU_11_AMD64_VERSION="${LIFERAY_DOCKER_ZULU_11_AMD64_VERSION}" \
			--build-arg LABEL_ZULU_11_ARM64_VERSION="${LIFERAY_DOCKER_ZULU_11_ARM64_VERSION}" \
			--builder "liferay-buildkit" \
			--platform "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" \
			--push \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	else
		remove_temp_dockerfile_target_platform

		docker build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_NAME="Liferay JDK11" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${image_version}" \
			--build-arg LABEL_ZULU_11_AMD64_VERSION="${LIFERAY_DOCKER_ZULU_11_AMD64_VERSION}" \
			--build-arg LABEL_ZULU_11_ARM64_VERSION="${LIFERAY_DOCKER_ZULU_11_ARM64_VERSION}" \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	fi
}

function main {
	delete_local_images "liferay/jdk11"

	make_temp_directory templates/jdk11

	log_in_to_docker_hub

	build_docker_image "${1}"

	clean_up_temp_directory
}

main "${@}"
