#!/bin/bash

source ./_common.sh

function build_docker_image {
	local docker_image_name=${2}
	local release_version=${3}

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="${docker_image_name}-${release_version}" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL=$(git config --get remote.origin.url) \
		--build-arg LABEL_VERSION="${release_version}" \
		--tag ${docker_image_name}:${release_version}-${TIMESTAMP} \
		--tag ${docker_image_name}:${release_version} \
		${TEMP_DIR}
}

function check_usage {
	if [ ! -n "${3}" ]
	then
		echo "Usage: ${0} path-to-bundle image-name version"
		echo ""
		echo "Example: ${0} ../bundles/master portal-snapshot demo-cbe09fb0"

		exit 1
	fi

	check_utils curl docker java
}

function main {
	check_usage ${@}

	make_temp_directory

	prepare_temp_directory ${@}

	prepare_tomcat

	build_docker_image ${@}

	clean_up_temp_directory
}

function prepare_temp_directory {
	cp -a ${1} ${TEMP_DIR}/liferay
}

main ${@}