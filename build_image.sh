#!/bin/bash

source ./_common.sh

function build_docker_image {
	local docker_image_name
	local label_name

	if [[ ${RELEASE_FILE_NAME} == *-commerce-enterprise-* ]]
	then
		docker_image_name="commerce-enterprise"
		label_name="Liferay Commerce Enterprise"
	elif [[ ${RELEASE_FILE_NAME} == *-commerce-* ]]
	then
		docker_image_name="commerce"
		label_name="Liferay Commerce"
	elif [[ ${RELEASE_FILE_NAME} == *-dxp-* ]] || [[ ${RELEASE_FILE_NAME} == *-private* ]]
	then
		docker_image_name="dxp"
		label_name="Liferay DXP"
	elif [[ ${RELEASE_FILE_NAME} == *-portal-* ]]
	then
		docker_image_name="portal"
		label_name="Liferay Portal"
	else
		echo "${RELEASE_FILE_NAME} is an unsupported release file name."

		exit 1
	fi

	if [[ ${RELEASE_FILE_URL%} == */snapshot-* ]]
	then
		docker_image_name=${docker_image_name}-snapshot
	fi

	if [[ ${RELEASE_FILE_URL} == http://release* ]]
	then
		docker_image_name=${docker_image_name}-snapshot
	fi

	local release_version=${RELEASE_FILE_URL%/*}

	release_version=${release_version##*/}

	if [[ ${RELEASE_FILE_URL} == http://release* ]]
	then
		release_version=${RELEASE_FILE_URL#*tomcat-}
		release_version=${release_version%.*}
	fi

	local label_version=${release_version}

	if [[ ${RELEASE_FILE_URL%} == */snapshot-* ]]
	then
		local release_branch=${RELEASE_FILE_URL%/*}

		release_branch=${release_branch%/*}
		release_branch=${release_branch%-private*}
		release_branch=${release_branch##*-}

		local release_hash=$(cat ${TEMP_DIR}/liferay/.githash)

		release_hash=${release_hash:0:7}

		if [[ ${release_branch} == master ]]
		then
			label_version="Master Snapshot on ${label_version} at ${release_hash}"
		else
			label_version="${release_branch} Snapshot on ${label_version} at ${release_hash}"
		fi
	fi

	DOCKER_IMAGE_TAGS=()

	if [[ ${RELEASE_FILE_URL%} == */snapshot-* ]]
	then
		DOCKER_IMAGE_TAGS+=("liferay/${docker_image_name}:${release_branch}-${release_version}-${release_hash}")
		DOCKER_IMAGE_TAGS+=("liferay/${docker_image_name}:${release_branch}-$(date "${CURRENT_DATE}" "+%Y%m%d")")
		DOCKER_IMAGE_TAGS+=("liferay/${docker_image_name}:${release_branch}")
	else
		DOCKER_IMAGE_TAGS+=("liferay/${docker_image_name}:${release_version}-${TIMESTAMP}")
		DOCKER_IMAGE_TAGS+=("liferay/${docker_image_name}:${release_version}")
	fi

	local docker_image_tags_args=""

	for docker_image_tag in "${DOCKER_IMAGE_TAGS[@]}"
	do
		docker_image_tags_args="${docker_image_tags_args} --tag ${docker_image_tag}"
	done

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_NAME="${label_name}" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
		--build-arg LABEL_VERSION="${label_version}" \
		$(echo ${docker_image_tags_args}) \
		${TEMP_DIR}
}

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} release-url <push>"
		echo ""
		echo "Example: ${0} files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z"
		echo ""
		echo "Set \"push\" as the second parameter to automatically push the image to Docker Hub."

		exit 1
	fi

	check_utils 7z curl docker java unzip
}

function download_trial_dxp_license {
	if [[ ${RELEASE_FILE_NAME} == *-commerce-enterprise-* ]] || [[ ${RELEASE_FILE_NAME} == *-dxp-* ]]
	then
		if [ -z "${LIFERAY_DOCKER_LICENSE_CMD}" ]
		then
			echo "Please set the environment variable LIFERAY_DOCKER_LICENSE_CMD to generate a trial DXP license."

			exit 1
		else
			mkdir -p ${TEMP_DIR}/liferay/deploy

			license_file_name=license-$(date "${CURRENT_DATE}" "+%Y%m%d").xml

			eval "curl --silent --header \"${LIFERAY_DOCKER_LICENSE_CMD}?licenseLifetime=$(expr 1000 \* 60 \* 60 \* 24 \* 30)&startDate=$(date "${CURRENT_DATE}" "+%Y-%m-%d")&owner=hello%40liferay.com\" > ${TEMP_DIR}/liferay/deploy/${license_file_name}"

			sed -i "s/\\\n//g" ${TEMP_DIR}/liferay/deploy/${license_file_name}
			sed -i "s/\\\t//g" ${TEMP_DIR}/liferay/deploy/${license_file_name}
			sed -i "s/\"<?xml/<?xml/" ${TEMP_DIR}/liferay/deploy/${license_file_name}
			sed -i "s/license>\"/license>/" ${TEMP_DIR}/liferay/deploy/${license_file_name}
			sed -i 's/\\"/\"/g' ${TEMP_DIR}/liferay/deploy/${license_file_name}
			sed -i 's/\\\//\//g' ${TEMP_DIR}/liferay/deploy/${license_file_name}

			if [ ! -e ${TEMP_DIR}/liferay/deploy/${license_file_name} ]
			then
				echo "Trial DXP license does not exist at ${TEMP_DIR}/liferay/deploy/${license_file_name}."

				exit 1
			else
				echo "Trial DXP license exists at ${TEMP_DIR}/liferay/deploy/${license_file_name}."

				#exit 1
			fi
		fi
	fi

	if [[ ${RELEASE_FILE_NAME} == *-commerce-enterprise-* ]]
	then
		mkdir -p ${TEMP_DIR}/liferay/data/license

		cp LiferayCommerce_enterprise.li ${TEMP_DIR}/liferay/data/license
	fi
}

function main {
	check_usage ${@}

	make_temp_directory

	prepare_temp_directory ${@}

	prepare_tomcat

	download_trial_dxp_license

	build_docker_image

	push_docker_images ${2}

	clean_up_temp_directory
}

function prepare_temp_directory {
	RELEASE_FILE_NAME=${1##*/}

	RELEASE_FILE_URL=${1}

	if [[ ${RELEASE_FILE_URL} != http://mirrors.*.liferay.com* ]] && [[ ${RELEASE_FILE_URL} != http://release* ]]
	then
		RELEASE_FILE_URL=http://mirrors.lax.liferay.com/${RELEASE_FILE_URL}
	fi

	local release_dir=${1%/*}

	release_dir=${release_dir#*com/}
	release_dir=${release_dir#*com/}
	release_dir=${release_dir#*liferay-release-tool/}
	release_dir=${release_dir#*private/ee/}
	release_dir=releases/${release_dir}

	if [ ! -e ${release_dir}/${RELEASE_FILE_NAME} ]
	then
		echo ""
		echo "Downloading ${RELEASE_FILE_URL}."
		echo ""

		mkdir -p ${release_dir}

		curl -f -o ${release_dir}/${RELEASE_FILE_NAME} ${RELEASE_FILE_URL} || exit 2
	fi

	if [[ ${RELEASE_FILE_NAME} == *.7z ]]
	then
		7z x -O${TEMP_DIR} ${release_dir}/${RELEASE_FILE_NAME} || exit 3
	else
		unzip -q ${release_dir}/${RELEASE_FILE_NAME} -d ${TEMP_DIR}  || exit 3
	fi

	mv ${TEMP_DIR}/liferay-* ${TEMP_DIR}/liferay
}

main ${@}