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
		echo "Usage: ${0} path-to-bundle image-name version <push> [no_warm_up] [no_test_image]"
		echo ""
		echo "Example: ${0} ../bundles/master portal-snapshot demo-cbe09fb0 <push>"

		exit 1
	fi

	check_utils curl docker java rsync
}

function main {
	check_usage "${@}"

	make_temp_directory templates/bundle

	prepare_temp_directory "${@}"

	prepare_tomcat "${@}"

	curl -q https://raw.githubusercontent.com/liferay/liferay-portal/master/tools/servers/tomcat/bin/setenv.sh \
		-o "${TEMP_DIR}/liferay/tomcat/bin/setenv.sh"

	build_docker_image "${@}"

	test_docker_image "${@}"

	clean_up_temp_directory
}

function prepare_temp_directory {
	rsync -aq "${1}" "${TEMP_DIR}/liferay" \
		--exclude '*.zip' \
		--exclude 'portal-setup-wizard.properties' \
		--exclude 'data/elasticsearch*' \
		--exclude 'logs/*' \
		--exclude 'osgi/state' \
		--exclude 'osgi/test' \
		--exclude 'tmp'
}

main "${@}"