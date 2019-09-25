#!/bin/bash

. ./build_common.sh

function main {
	if [ ! -n "${3}" ]
	then
		echo "Usage: ${0} path-to-bundle image-name version"
		echo ""
		echo "Example: ${0} ../bundles portal-snapshot demo-cbe09fb0414"

		exit 1
	fi

	check_utils curl docker java

	#
	# Make temporary directory.
	#

	local current_date=$(date)

	local timestamp=$(date "${current_date}" "+%Y%m%d%H%M")

	local temp_dir=temp-${timestamp}

	mkdir -p ${temp_dir}

	cp -r template/* ${temp_dir}

	#
	# Download and prepare release.
	#

	local local_build_dir=${1}

	cp -a ${local_build_dir} ${temp_dir}/liferay

	#
	# Configure Tomcat.
	#

	local liferay_tomcat_version=$(get_tomcat_version ${temp_dir}/liferay)

	mv ${temp_dir}/liferay/tomcat-${liferay_tomcat_version} ${temp_dir}/liferay/tomcat

	ln -s tomcat ${temp_dir}/liferay/tomcat-${liferay_tomcat_version}

	configure_tomcat ${temp_dir}

	#
	# Warm up Tomcat for older versions to speed up starting Tomcat. Populating
	# the Hypersonic files can take over 20 seconds.
	#

	warm_up_tomcat ${temp_dir}

	#
	# Build Docker image.
	#

	local docker_image_name=${2}
	local release_version=${3}
	local label_name=${docker_image_name}-${release_version}
	local label_version=${release_version}

	local docker_image_tags=()

	docker_image_tags+=("liferay/${docker_image_name}:${release_version}-${timestamp}")
	docker_image_tags+=("liferay/${docker_image_name}:${release_version}")

	local docker_image_tags_args=""

	for docker_image_tag in "${docker_image_tags[@]}"
	do
		docker_image_tags_args="${docker_image_tags_args} --tag ${docker_image_tag}"
	done

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${current_date}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="${label_name}" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VERSION="${label_version}" \
		$(echo ${docker_image_tags_args}) \
		${temp_dir}

	#
	# Clean up temporary directory.
	#

	rm -fr ${temp_dir}
}


main ${1} ${2} ${3}