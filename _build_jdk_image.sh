#!/bin/bash

source ./_common.sh

function _build_docker_image {
	local jdk_friendly_name="${2}"
	local jdk_from_image_name="${3}"
	local jdk_image_name="${4}"
	local jdk_version="${5}"

	delete_local_images "${LIFERAY_DOCKER_REPOSITORY}/${jdk_image_name}"

	make_temp_directory templates/_jdk

	sed -i "s/@jdk_from_image_name@/${jdk_from_image_name}/g" "${TEMP_DIR}"/Dockerfile
	sed -i "s/@jdk_version@/${jdk_version}/g" "${TEMP_DIR}"/Dockerfile

	log_in_to_docker_hub

	local image_version=$(./release_notes.sh get-version)

	DOCKER_IMAGE_TAGS=()
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${jdk_image_name}:${image_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${jdk_image_name}")

	local zulu_amd64_version="LIFERAY_DOCKER_ZULU_AMD64_VERSION"
	local zulu_arm64_version="LIFERAY_DOCKER_ZULU_ARM64_VERSION"

	if [ "${1}" == "push" ]
	then
		check_docker_buildx

		docker buildx build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_NAME="Liferay ${jdk_friendly_name}" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${image_version}" \
			--build-arg LABEL_ZULU_${jdk_version}_AMD64_VERSION="${!zulu_amd64_version}" \
			--build-arg LABEL_ZULU_${jdk_version}_ARM64_VERSION="${!zulu_arm64_version}" \
			--builder "liferay-buildkit" \
			--platform "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" \
			--push \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	else
		remove_temp_dockerfile_target_platform

		docker build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_NAME="Liferay ${jdk_friendly_name}" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${image_version}" \
			--build-arg LABEL_ZULU_${jdk_version}_AMD64_VERSION="${!zulu_amd64_version}" \
			--build-arg LABEL_ZULU_${jdk_version}_ARM64_VERSION="${!zulu_arm64_version}" \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	fi

	clean_up_temp_directory
}