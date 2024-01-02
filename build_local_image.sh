#!/bin/bash

source ./_common.sh

function build_docker_image {
	local docker_image_name=${2}
	local release_version=${3}

	DOCKER_IMAGE_TAGS=()

	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}${docker_image_name}:${release_version}-${TIMESTAMP}")
	DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}${docker_image_name}:${release_version}")

	remove_temp_dockerfile_target_platform

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="${docker_image_name}-${release_version}" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL=$(git config --get remote.origin.url) \
		--build-arg LABEL_VERSION="${release_version}" \
		$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
		"${TEMP_DIR}"
}

function check_usage {
	if [ ! -n "${3}" ]
	then
		echo "Usage: ${0} path-to-bundle/ image-name version --no-warm-up --no-test-image --push"
		echo ""
		echo "Example: ${0} ../bundles/master/ portal-snapshot demo-cbe09fb0 --no-warm-up --no-test-image"

		exit 1
	fi

	check_utils curl docker java rsync
}

function main {
	check_usage "${@}"

	make_temp_directory templates/bundle

	prepare_temp_directory "${@}"

	prepare_tomcat "${@}"

	build_docker_image "${@}"

	test_docker_image "${@}"

	clean_up_temp_directory
}

function prepare_temp_directory {
	rsync -aq \
		--exclude "*.zip" \
		--exclude "data/elasticsearch*" \
		--exclude "logs/*" \
		--exclude "osgi/state" \
		--exclude "osgi/test" \
		--exclude "portal-setup-wizard.properties" \
		--exclude "tmp" \
		"${1}" "${TEMP_DIR}/liferay"
}

main "${@}"