#!/bin/bash

source ./_common.sh

BUILD_ALL_IMAGES_PUSH=${1}

function build_base_image {
	log_in_to_docker_hub

	if [[ $(get_latest_docker_hub_version "base") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image base is up to date."

		return
	fi

	echo ""
	echo "Building Docker image base."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" time ./build_base_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/base.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Base" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Base" >> "${LOGS_DIR}/results"
	fi
}

function build_bundle_image {
	local query=${1}
	local version=${2}

	local additional_tags=$(get_string $( yq "${query}".additional_tags < bundles.yml))
	local bundle_url=$(get_string $(yq "${query}".bundle_url < bundles.yml))
	local fix_pack_url=$(get_string $(yq "${query}".fix_pack_url < bundles.yml))
	local test_hotfix_url=$(get_string $(yq "${query}".test_hotfix_url < bundles.yml))
	local test_installed_patch=$(get_string $( yq "${query}".test_installed_patch < bundles.yml))

	if [ -n "${additional_tags}" ]
	then
		version="${version},${additional_tags}"
	fi

	if [ ! -n "${version}" ]
	then
		local build_id=${bundle_url##*/}
	else
		local build_id=${version}
	fi

	echo ""
	echo "Building Docker image ${build_id} based on ${bundle_url}."
	echo ""

	LIFERAY_DOCKER_FIX_PACK_URL=${fix_pack_url} LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_RELEASE_FILE_URL=${bundle_url} LIFERAY_DOCKER_RELEASE_VERSION=${version} LIFERAY_DOCKER_TEST_HOTFIX_URL=${test_hotfix_url} LIFERAY_DOCKER_TEST_INSTALLED_PATCHES=${test_installed_patch} time ./build_bundle_image.sh "${BUILD_ALL_IMAGES_PUSH}" 2>&1 | tee "${LOGS_DIR}/${build_id}.log"

	local build_bundle_image_exit_code=${PIPESTATUS[0]}

	if [ "${build_bundle_image_exit_code}" -gt 0 ]
	then
		echo "FAILED: ${build_id}" >> "${LOGS_DIR}/results"

		if [ "${build_bundle_image_exit_code}" -eq 4 ]
		then
			echo "Detected a license failure while building image ${build_id}." > "${LOGS_DIR}/license-failure"

			echo "There is an existing license failure."

			exit 4
		fi
	else
		echo "SUCCESS: ${build_id}" >> "${LOGS_DIR}/results"
	fi
}

function build_bundle_images {

	#
	# LIFERAY_DOCKER_IMAGE_FILTER="7.2.10-dxp-1 "  ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=7.2.10 ./build_all_images.sh
	#

	local main_keys=$(yq '' < bundles.yml | grep -v '  .*' | sed 's/://')

	local specified_version=${LIFERAY_DOCKER_IMAGE_FILTER}

	if [ -z "${LIFERAY_DOCKER_IMAGE_FILTER}" ]
	then
		specified_version="*"
	fi

	local search_output=$(yq .\""${specified_version}"\" < bundles.yml)

	if [[ "${search_output}" != "null" ]]
	then
		local versions=$(echo "${search_output}"  | grep '^.*:$' | sed 's/://')

		for version in ${versions}
		do
			local query=.\"$(get_main_key "${main_keys}" "${version}")\".\"${version}\"

			build_bundle_image "${query}" "${version}"
		done
	else
		local main_key=$(get_main_key "${main_keys}" "${specified_version}")

		if [[ "${main_key}" = "null" ]]
		then
			echo "No bundles were found."

			exit 1
		else
			local query=.\"${main_key}\".\"${specified_version}\"

			if [[ "$(yq "${query}" < bundles.yml)" != "null" ]]
			then
				build_bundle_image "${query}" "${specified_version}"
			else
				echo "No bundles were found."

				exit 1
			fi
		fi
	fi
}

function build_jdk11_image {
	local jdk11_image_version=1.0
	local latest_available_zulu11_version=$(get_latest_available_zulu_version "11")

	if [[ $(get_latest_docker_hub_zulu_version "jdk11" "11") == "${latest_available_zulu11_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image JDK 11 is up to date."

		return
	fi

	echo ""
	echo "Building Docker image JDK 11."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_ZULU_11_VERSION=${latest_available_zulu11_version} time ./build_jdk11_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/jdk11.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: JDK 11" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: JDK 11" >> "${LOGS_DIR}/results"
	fi
}

function build_jdk11_jdk8_image {
	local jdk11_jdk8_image_version=1.0
	local latest_available_zulu8_version=$(get_latest_available_zulu_version "8")

	if [[ $(get_latest_docker_hub_zulu_version "jdk11-jdk8" "8") == "${latest_available_zulu8_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image JDK 8 is up to date."

		return
	fi

	echo ""
	echo "Building Docker image JDK 11/JDK 8."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_ZULU_8_VERSION=${latest_available_zulu8_version} time ./build_jdk11_jdk8_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/jdk11_jdk8.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: JDK 11/JDK 8" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: JDK 11/JDK 8" >> "${LOGS_DIR}/results"
	fi
}

function build_job_runner_image {
	if [[ $(get_latest_docker_hub_version "job-runner") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image job runner is up to date."

		return
	fi

	local job_runner_version=1.0

	echo ""
	echo "Building Docker image job runner."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" time ./build_job_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/job_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Job Runner" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Job Runner" >> "${LOGS_DIR}/results"
	fi
}

function get_latest_available_zulu_version {
	local version=$(curl -L -s -H 'accept: */*' "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=${1}&os=linux" | jq -r '.zulu_version | join(".")' | cut -f1,2,3 -d'.')

	echo "${version}"
}

function get_latest_docker_hub_version {
	local token=$(curl -s "https://auth.docker.io/token?scope=repository:liferay&service=registry.docker.io/${1}:pull" | jq -r '.token')

	local version=$(curl -s  -H "Authorization: Bearer $token" "https://registry-1.docker.io/v2/liferay/${1}/manifests/latest" | grep -o '\\"org.label-schema.version\\":\\"[0-9]\.[0-9]\.[0-9]*\\"' | head -1 | sed 's/\\"//g' | sed 's:.*\:::')

	echo "${version}"
}

function get_latest_docker_hub_zulu_version {
	local token=$(curl -s "https://auth.docker.io/token?scope=repository:liferay&service=registry.docker.io/${1}:pull" | jq -r '.token')

	local version=$(curl -s  -H "Authorization: Bearer $token" "https://registry-1.docker.io/v2/liferay/${1}/manifests/latest" | grep -o "\\\\\"org.label-schema.zulu${2}_version\\\\\":\\\\\"[0-9]*\.[0-9]*\.[0-9]*\\\\\"" | head -1 | sed 's/\\"//g' | sed 's:.*\:::')

	echo "${version}"
}

function get_main_key {
	local main_keys=${1}
	local version=${2}

	for main_key in ${main_keys}
	do
		local count=$(echo "${version}" | grep -c -E "${main_key}-|${main_key}\.")

		if [ "${count}" -gt 0 ]
		then
			echo "${main_key}"

			break
		fi
	done
}

function get_string {
	if [ "${1}" == "null" ]
	then
		echo ""
	else
		echo "${1}"
	fi
}

function main {
	if [ "${BUILD_ALL_IMAGES_PUSH}" == "push" ] && ! ./release_notes.sh fail-on-change
	then
		exit 1
	fi

	if [ "${BUILD_ALL_IMAGES_PUSH}" == "push" ] && [ -z ${LIFERAY_DOCKER_IMAGE_PLATFORMS} ]
	then
		LIFERAY_DOCKER_IMAGE_PLATFORMS=linux/amd64,linux/arm64
	fi

	LOGS_DIR=logs-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p "${LOGS_DIR}"

	build_base_image

	build_jdk11_image

	build_jdk11_jdk8_image

	build_job_runner_image

	build_bundle_images

	echo ""
	echo "Results: "
	echo ""

	cat "${LOGS_DIR}/results"
}

main