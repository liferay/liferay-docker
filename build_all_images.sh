#!/bin/bash

source ./_common.sh

function build_base_image {
	log_in_to_docker_hub

	if [[ $(get_latest_docker_hub_version "base") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Base is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Base."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_base_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/base.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Base" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Base" >> "${LOGS_DIR}/results"
	fi
}

function build_batch_image {
	if [[ $(get_latest_docker_hub_version "batch") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Batch is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Batch."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_batch_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/batch.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Batch" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Batch" >> "${LOGS_DIR}/results"
	fi
}

function build_bundle_image {
	local query=${1}
	local version=${2}

	local additional_tags=$(get_string $( yq "${query}".additional_tags < bundles.yml))
	local bundle_url=$(get_string $(yq "${query}".bundle_url < bundles.yml))
	local fix_pack_url=$(get_string $(yq "${query}".fix_pack_url < bundles.yml))
	local latest=$(get_string $(yq "${query}".latest < bundles.yml))
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

	LIFERAY_DOCKER_FIX_PACK_URL=${fix_pack_url} LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_LATEST=${latest} LIFERAY_DOCKER_RELEASE_FILE_URL=${bundle_url} LIFERAY_DOCKER_RELEASE_VERSION=${version} LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_TEST_HOTFIX_URL=${test_hotfix_url} LIFERAY_DOCKER_TEST_INSTALLED_PATCHES=${test_installed_patch} time ./build_bundle_image.sh "${BUILD_ALL_IMAGES_PUSH}" 2>&1 | tee "${LOGS_DIR}/${build_id}.log"

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
	# LIFERAY_DOCKER_IMAGE_FILTER="7.2.10-dxp-1 " ./build_all_images.sh
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
		local versions=$(echo "${search_output}" | grep '^.*:$' | sed 's/://')

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

function build_caddy_image {
	if [[ $(get_latest_docker_hub_version "caddy") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Caddy is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Caddy resources."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_caddy_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/caddy.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Caddy" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Caddy" >> "${LOGS_DIR}/results"
	fi
}

function build_dynamic_rendering_image {
	if [[ $(get_latest_docker_hub_version "job-runner") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Dynamic Rendering is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Dynamic Rendering."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_dynamic_rendering_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/dynamic_rendering.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Dynamic Rendering" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Dynamic Rendering" >> "${LOGS_DIR}/results"
	fi
}

function build_jar_runner_image {
	if [[ $(get_latest_docker_hub_version "jar-runner") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image JAR Runner is up to date."

		return
	fi

	echo ""
	echo "Building Docker image JAR Runner."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_jar_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/jar_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: JAR Runner" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: JAR Runner" >> "${LOGS_DIR}/results"
	fi
}

function build_jdk11_image {
	local latest_available_zulu11_amd64_version=$(get_latest_available_zulu_version "11" "amd64")
	local latest_available_zulu11_arm64_version=$(get_latest_available_zulu_version "11" "arm64")

	if [[ $(get_latest_docker_hub_zulu_version "jdk11" "11" "amd64") == "${latest_available_zulu11_amd64_version}" ]] && [[ $(get_latest_docker_hub_zulu_version "jdk11" "11" "arm64") == "${latest_available_zulu11_arm64_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image JDK 11 is up to date."

		return
	fi

	echo ""
	echo "Building Docker image JDK 11."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZULU_11_AMD64_VERSION=${latest_available_zulu11_amd64_version} LIFERAY_DOCKER_ZULU_11_ARM64_VERSION=${latest_available_zulu11_arm64_version} time ./build_jdk11_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/jdk11.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: JDK 11" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: JDK 11" >> "${LOGS_DIR}/results"
	fi
}

function build_jdk11_jdk8_image {
	local latest_available_zulu8_amd64_version=$(get_latest_available_zulu_version "8" "amd64")
	local latest_available_zulu8_arm64_version=$(get_latest_available_zulu_version "8" "arm64")

	if [[ $(get_latest_docker_hub_zulu_version "jdk11-jdk8" "8" "amd64") == "${latest_available_zulu8_amd64_version}" ]] && [[ $(get_latest_docker_hub_zulu_version "jdk11-jdk8" "8" "arm64") == "${latest_available_zulu8_arm64_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image JDK 8 is up to date."

		return
	fi

	echo ""
	echo "Building Docker image JDK 11/JDK 8."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZULU_8_AMD64_VERSION=${latest_available_zulu8_amd64_version} LIFERAY_DOCKER_ZULU_8_ARM64_VERSION=${latest_available_zulu8_arm64_version} time ./build_jdk11_jdk8_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/jdk11_jdk8.log

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
		echo "Docker image Job Runner is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Job Runner."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_job_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/job_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Job Runner" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Job Runner" >> "${LOGS_DIR}/results"
	fi
}

function build_node_runner_image {
	if [[ $(get_latest_docker_hub_version "node-runner") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Node Runner is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Node Runner."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_node_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/node_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Node Runner" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Node Runner" >> "${LOGS_DIR}/results"
	fi
}

function build_noop_image {
	if [[ $(get_latest_docker_hub_version "noop") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image NOOP is up to date."

		return
	fi

	echo ""
	echo "Building Docker image NOOP."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_noop_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/noop.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: NOOP" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: NOOP" >> "${LOGS_DIR}/results"
	fi
}

function build_zabbix_server_image {
	local latest_liferay_zabbix_server_version=$(get_latest_docker_hub_zabbix_server_version "liferay/zabbix-server")
	local latest_official_zabbix_server_version=$(get_latest_docker_hub_zabbix_server_version "zabbix/zabbix-server-mysql")

	if [[ "${latest_liferay_zabbix_server_version}" == "${latest_official_zabbix_server_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Zabbix Server is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Zabbix Server."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZABBIX_VERSION=${latest_official_zabbix_server_version} time ./build_zabbix_server_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/zabbix_server.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Zabbix Server" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Zabbix Server" >> "${LOGS_DIR}/results"
	fi
}

function build_zabbix_web_image {
	local latest_liferay_zabbix_server_web_interface_version=$(get_latest_docker_hub_zabbix_server_version "liferay/zabbix-web")
	local latest_official_zabbix_server_web_interface_version=$(get_latest_docker_hub_zabbix_server_version "zabbix/zabbix-web-nginx-mysql")

	if [[ "${latest_liferay_zabbix_server_web_interface_version}" == "${latest_official_zabbix_server_web_interface_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Zabbix Web is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Zabbix Web."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZABBIX_VERSION=${latest_official_zabbix_server_web_interface_version} time ./build_zabbix_web_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/zabbix_server_web_interface.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Zabbix Web" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Zabbix Web" >> "${LOGS_DIR}/results"
	fi
}

function get_latest_available_zulu_version {
	local version=$(curl -H 'accept: */*' -L -s "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?arch=${2}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=${1}&os=linux" | jq -r '.zulu_version | join(".")' | cut -f1,2,3 -d'.')

	echo "${version}"
}

function get_latest_docker_hub_version {
	local token=$(curl -s "https://auth.docker.io/token?scope=repository:liferay/${1}:pull&service=registry.docker.io" | jq -r '.token')

	local version=$(curl -s -H "Authorization: Bearer $token" "https://registry-1.docker.io/v2/liferay/${1}/manifests/latest" | grep -o '\\"org.label-schema.version\\":\\"[0-9]\.[0-9]\.[0-9]*\\"' | head -1 | sed 's/\\"//g' | sed 's:.*\:::')

	if [ -z "${version}" ]
	then
		docker pull "liferay/${1}:latest" >/dev/null

		if [ $? -gt 0 ]
		then
			version="0"
		else
			version=$(docker image inspect --format '{{index .Config.Labels "org.label-schema.version"}}' "liferay/${1}:latest")
		fi

		echo "${version}"
	else
		echo "${version}"
	fi
}

function get_latest_docker_hub_zabbix_server_version {
	local image_tag="${1}"

	local token=$(curl -s "https://auth.docker.io/token?scope=repository:${image_tag}:pull&service=registry.docker.io" | jq -r '.token')

	local label_name="org.opencontainers.image.version"
	local tag="ubuntu-latest"

	if [[ "${image_tag}" =~ "liferay/" ]]
	then
		label_name="org.label-schema.zabbix-version"
		tag="latest"
	fi

	local version=$(curl -s -H "Authorization: Bearer $token" "https://registry-1.docker.io/v2/${image_tag}/manifests/${tag}" | grep -o "\\\\\"${label_name}\\\\\":\\\\\"[0-9]*\.[0-9]*\.[0-9]*\\\\\"" | head -1 | sed 's/\\"//g' | sed 's:.*\:::')

	echo "${version}"
}

function get_latest_docker_hub_zulu_version {
	local token=$(curl -s "https://auth.docker.io/token?scope=repository:liferay/${1}:pull&service=registry.docker.io" | jq -r '.token')

	local version=$(curl -s -H "Authorization: Bearer $token" "https://registry-1.docker.io/v2/liferay/${1}/manifests/latest" | grep -o "\\\\\"org.label-schema.zulu${2}_${3}_version\\\\\":\\\\\"[0-9]*\.[0-9]*\.[0-9]*\\\\\"" | head -1 | sed 's/\\"//g' | sed 's:.*\:::')

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
	check_utils 7z curl docker git java jq sed sort tr unzip yq

	if [[ " ${@} " =~ " --push " ]]
	then
		BUILD_ALL_IMAGES_PUSH="push"

		./release_notes.sh commit

		git push
	fi

	if [ "${BUILD_ALL_IMAGES_PUSH}" == "push" ] && [ -z "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" ]
	then
		LIFERAY_DOCKER_IMAGE_PLATFORMS=linux/amd64,linux/arm64
	fi

	if [ -z "${LIFERAY_DOCKER_REPOSITORY}" ]
	then
		LIFERAY_DOCKER_REPOSITORY=liferay
	fi

	validate_bundles_yml

	LOGS_DIR=logs-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p "${LOGS_DIR}"

	build_base_image

	build_jdk11_image
	build_jdk11_jdk8_image

	build_batch_image
	build_caddy_image
	build_jar_runner_image
	build_job_runner_image
	build_node_runner_image
	build_noop_image
	build_zabbix_server_image
	build_zabbix_web_image

	build_bundle_images

	echo ""
	echo "Results: "
	echo ""

	cat "${LOGS_DIR}/results"

	if [ $(grep -c "FAILED" "${LOGS_DIR}/results") != 0 ]
	then
		exit 1
	fi
}

function validate_bundles_yml {
	if [ $(yq '.*.*.latest' < bundles.yml | grep "true" -c) -gt 2 ]
	then
		echo "There are too many images designated as latest."

		exit 1
	fi

	local dxp_latest_key_counter=0
	local main_keys=$(yq '' < bundles.yml | grep -v '  .*' | sed 's/://')
	local portal_latest_key_counter=0

	for main_key in ${main_keys}
	do
		if [ $(yq .\""${main_key}"\".*.latest < bundles.yml | grep "true\|false" -c) -gt 0 ]
		then
			local minor_keys=$(yq .\""${main_key}"\" < bundles.yml | grep -v '  .*' | sed 's/://')

			for minor_key in ${minor_keys}
			do
				if [ $(yq .\""${main_key}"\".\""${minor_key}"\".latest < bundles.yml | grep "true\|false" -c) -gt 0 ]
				then
					if [ $(yq .\""${main_key}"\".\""${minor_key}"\".bundle_url < bundles.yml | grep "portal-tomcat") ]
					then
						portal_latest_key_counter=$((portal_latest_key_counter+1))
					elif [ $(yq .\""${main_key}"\".\""${minor_key}"\".bundle_url < bundles.yml | grep "dxp-tomcat") ]
					then
						dxp_latest_key_counter=$((dxp_latest_key_counter+1))
					fi
				fi
			done
		fi
	done

	if [ ${dxp_latest_key_counter} -gt 1 ]
	then
		echo "There are ${dxp_latest_key_counter} latest DXP images."

		exit 1
	elif [ ${portal_latest_key_counter} -gt 1 ]
	then
		echo "There are ${portal_latest_key_counter} latest portal images."

		exit 1
	fi
}

main "${@}"