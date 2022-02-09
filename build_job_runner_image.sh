#!/bin/bash

source ./_common.sh

function build_docker_image {
	local base_image_version=$(./release_notes.sh get-version)
	local job_runner_image_version=0.1.5

	DOCKER_IMAGE_TAGS=()
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/job-runner:${job_runner_image_version}-d${base_image_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}liferay/job-runner:${job_runner_image_version%.*}")

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="Liferay Job Runner" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
		--build-arg LABEL_VERSION="${job_runner_image_version}" \
		$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
		"${TEMP_DIR}"
}

function main {
	make_temp_directory templates/job-runner

	build_docker_image

	log_in_to_docker_hub

	push_docker_images "${1}"

	clean_up_temp_directory
}

main "${@}"