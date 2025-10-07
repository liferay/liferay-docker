#!/bin/bash

source ./_common.sh
source ./_liferay_common.sh
source ./_release_common.sh

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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_base_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/base.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Base" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Base" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_batch_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/batch.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Batch" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Batch" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
	fi
}

function build_bundle_image {
	local query=${1}
	local slim=${2}
	local version=${3}

	local additional_tags=$(get_string $( yq "${query}".additional_tags < bundles.yml))
	local bundle_url=$(get_string $(yq "${query}".bundle_url < bundles.yml))
	local fix_pack_url=$(get_string $(yq "${query}".fix_pack_url < bundles.yml))
	local latest=$(get_string $(yq "${query}".latest < bundles.yml))
	local test_hotfix_url=$(get_string $(yq "${query}".test_hotfix_url < bundles.yml))
	local test_installed_patch=$(get_string $( yq "${query}".test_installed_patch < bundles.yml))

	if is_dxp_release && is_release_candidate
	then
		bundle_url="releases-cdn.liferay.com/dxp/release-candidates/${version}/$(curl -fsSL "https://releases-cdn.liferay.com/dxp/release-candidates/${version}/.lfrrelease-tomcat-bundle")"
	elif is_ga_release && is_release_candidate
	then
		bundle_url="releases-cdn.liferay.com/portal/release-candidates/${version}/$(curl -fsSL "https://releases-cdn.liferay.com/portal/release-candidates/${version}/.lfrrelease-tomcat-bundle")"
	fi

	if [ -z "${bundle_url}" ]
	then
		bundle_url="releases-cdn.liferay.com/dxp/${version}/"$(curl --fail --location --show-error --silent "https://releases-cdn.liferay.com/dxp/${version}/.lfrrelease-tomcat-bundle")
	fi

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

	local image_name="${build_id}"

	if [ "${slim}" == "true" ]
	then
		image_name="${image_name}-slim"
	fi

	echo ""
	echo "Building Docker image ${image_name} based on ${bundle_url}."
	echo ""

	LIFERAY_DOCKER_FIX_PACK_URL=${fix_pack_url} LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_LATEST=${latest} LIFERAY_DOCKER_RELEASE_CANDIDATE="${LIFERAY_DOCKER_RELEASE_CANDIDATE}" LIFERAY_DOCKER_RELEASE_FILE_URL=${bundle_url} LIFERAY_DOCKER_RELEASE_VERSION=${version} LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_SLIM="${slim}" LIFERAY_DOCKER_TEST_HOTFIX_URL=${test_hotfix_url} LIFERAY_DOCKER_TEST_INSTALLED_PATCHES=${test_installed_patch} time ./build_bundle_image.sh "${BUILD_ALL_IMAGES_PUSH}" 2>&1 | tee "${LIFERAY_DOCKER_LOGS_DIR}/${build_id}.log"

	local build_bundle_image_exit_code=${PIPESTATUS[0]}

	if [ "${build_bundle_image_exit_code}" -gt 0 ]
	then
		echo "FAILED: ${image_name}" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		if [ "${build_bundle_image_exit_code}" -eq 4 ]
		then
			echo "Detected a license failure while building image ${image_name}." > "${LIFERAY_DOCKER_LOGS_DIR}/license-failure"

			echo "There is an existing license failure."

			exit 4
		fi
	else
		echo "SUCCESS: ${image_name}" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
	fi
}

function build_bundle_images {

	#
	# LIFERAY_DOCKER_IMAGE_FILTER="7.2.10-dxp-1 " ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=7.2.10 ./build_all_images.sh
	#

	if is_release_candidate
	then
		echo "Building bundle images for release candidate ${LIFERAY_DOCKER_IMAGE_FILTER}."

		build_bundle_image "" "false" "${LIFERAY_DOCKER_IMAGE_FILTER}"

		return
	fi

	local main_keys=$(yq '' < bundles.yml | grep --invert-match '  .*' | sed "s/://")

	local specified_version=${LIFERAY_DOCKER_IMAGE_FILTER}

	if [ -z "${LIFERAY_DOCKER_IMAGE_FILTER}" ]
	then
		specified_version="*"
	fi

	local search_output=$(yq .\""${specified_version}"\" < bundles.yml)

	if [[ "${search_output}" != "null" ]]
	then
		local latest_7413_version=$( \
			yq '."7.4.13"' bundles.yml | \
			grep '^.*:$' | \
			sed "s/://" | \
			sed "s/.*-u//" | \
			sed "s/7.4.13.nightly//" | \
			sort --numeric-sort --reverse | \
			head --lines=1)

		local versions=$(echo "${search_output}" | grep '^.*:$' | sed "s/://")

		for version in ${versions}
		do
			local main_key=$(get_main_key "${main_keys}" "${version}")

			if [[ "${specified_version}" == "*" ]] && [[ "${main_key}" == "7.4.13" ]] && [[ "7.4.13-u${latest_7413_version}" != "${version}" ]]
			then
				continue
			fi

			local query=.\"${main_key}\".\"${version}\"

			if (has_slim_build_criteria "${version}")
			then
				build_bundle_image "${query}" "true" "${version}"
			fi

			build_bundle_image "${query}" "false" "${version}"
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
				if (has_slim_build_criteria "${specified_version}")
				then
					build_bundle_image "${query}" "true" "${specified_version}"
				fi

				build_bundle_image "${query}" "false" "${specified_version}"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_caddy_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/caddy.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Caddy" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Caddy" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_dynamic_rendering_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/dynamic_rendering.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Dynamic Rendering" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Dynamic Rendering" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_jar_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/jar_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: JAR Runner" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: JAR Runner" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
	fi
}

function build_jdk_image {
	local jdk_friendly_name="${1}"
	local jdk_image_name="${2}"
	local jdk_version="${3}"

	local latest_available_zulu_amd64_version=$(get_latest_available_zulu_version "amd64" "${jdk_version}")
	local latest_available_zulu_arm64_version=$(get_latest_available_zulu_version "arm64" "${jdk_version}")

	if [[ $(get_latest_docker_hub_zulu_version "${jdk_image_name}" "${jdk_version}" "amd64") == "${latest_available_zulu_amd64_version}" ]] && [[ $(get_latest_docker_hub_zulu_version "${jdk_image_name}" "${jdk_version}" "arm64") == "${latest_available_zulu_arm64_version}" ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image ${jdk_friendly_name} is up to date."

		return
	fi

	echo ""
	echo "Building Docker image ${jdk_friendly_name}."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZULU_AMD64_VERSION=${latest_available_zulu_amd64_version} LIFERAY_DOCKER_ZULU_ARM64_VERSION=${latest_available_zulu_arm64_version} time ./build_"$(echo "${jdk_image_name}" | sed --regexp-extended "s/-/_/g")"_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/"${jdk_image_name}".log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: ${jdk_friendly_name}" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: ${jdk_friendly_name}" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_job_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/job_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Job Runner" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Job Runner" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_node_runner_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/node_runner.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Node Runner" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Node Runner" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_noop_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/noop.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: NOOP" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: NOOP" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
	fi
}

function build_squid_image {
	if [[ $(get_latest_docker_hub_version "squid") == $(./release_notes.sh get-version) ]] && [[ "${LIFERAY_DOCKER_DEVELOPER_MODE}" != "true" ]]
	then
		echo ""
		echo "Docker image Squid is up to date."

		return
	fi

	echo ""
	echo "Building Docker image Squid resources."
	echo ""

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" time ./build_squid_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/squid.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Squid" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Squid" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZABBIX_VERSION=${latest_official_zabbix_server_version} time ./build_zabbix_server_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/zabbix_server.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Zabbix Server" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Zabbix Server" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
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

	LIFERAY_DOCKER_IMAGE_PLATFORMS="${LIFERAY_DOCKER_IMAGE_PLATFORMS}" LIFERAY_DOCKER_REPOSITORY="${LIFERAY_DOCKER_REPOSITORY}" LIFERAY_DOCKER_ZABBIX_VERSION=${latest_official_zabbix_server_web_interface_version} time ./build_zabbix_web_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee --append "${LIFERAY_DOCKER_LOGS_DIR}"/zabbix_server_web_interface.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: Zabbix Web" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: Zabbix Web" >> "${LIFERAY_DOCKER_LOGS_DIR}/results"
	fi
}

function get_latest_available_zulu_version {
	local version=$(\
		curl \
			--header 'accept: */*' \
			--location \
			--silent \
			"https://api.azul.com/zulu/download/community/v1.0/bundles/latest/?arch=${1}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=${2}&os=linux" | \
			jq --raw-output '.zulu_version | join(".")' | \
			cut --delimiter='.' --fields=1,2,3)

	echo "${version}"
}

function get_latest_docker_hub_version {
	local token=$(curl --silent "https://auth.docker.io/token?scope=repository:liferay/${1}:pull&service=registry.docker.io" | jq --raw-output '.token')

	local version=$(curl --header "Authorization: Bearer $token" --silent "https://registry-1.docker.io/v2/liferay/${1}/manifests/latest" | grep --only-matching '\\"org.label-schema.version\\":\\"[0-9]\.[0-9]\.[0-9]*\\"' | head -1 | sed 's/\\"//g' | sed "s:.*\:::")

	version=$(get_tag_from_image "${version}" "liferay/${1}" "org.label-schema.version:[0-9]*.[0-9]*.[0-9]*")

	echo "${version}"
}

function get_latest_docker_hub_zabbix_server_version {
	local image_tag="${1}"

	local token=$(curl --silent "https://auth.docker.io/token?scope=repository:${image_tag}:pull&service=registry.docker.io" | jq --raw-output '.token')

	local label_name="org.opencontainers.image.version"
	local tag="ubuntu-latest"

	if [[ "${image_tag}" =~ "liferay/" ]]
	then
		label_name="org.label-schema.zabbix-version"
		tag="latest"
	fi

	local version=$(curl --header "Authorization: Bearer $token" --silent "https://registry-1.docker.io/v2/${image_tag}/manifests/${tag}" | grep --only-matching "\\\\\"${label_name}\\\\\":\\\\\"[0-9]*\.[0-9]*\.[0-9]*\\\\\"" | head -1 | sed 's/\\"//g' | sed "s:.*\:::")

	version=$(get_tag_from_image "${version}" "${image_tag}" "${label_name}:[0-9]*.[0-9]*.[0-9]*")

	echo "${version}"
}

function get_latest_docker_hub_zulu_version {
	local token=$(curl --silent "https://auth.docker.io/token?scope=repository:liferay/${1}:pull&service=registry.docker.io" | jq --raw-output '.token')

	local version=$(curl --header "Authorization: Bearer $token" --silent "https://registry-1.docker.io/v2/liferay/${1}/manifests/latest" | grep --only-matching "\\\\\"org.label-schema.zulu${2}_${3}_version\\\\\":\\\\\"[0-9]*\.[0-9]*\.[0-9]*\\\\\"" | head -1 | sed 's/\\"//g' | sed "s:.*\:::")

	version=$(get_tag_from_image "${version}" "liferay/${1}" "org.label-schema.zulu${2}_${3}_version:[0-9]*.[0-9]*.[0-9]*")

	echo "${version}"
}

function get_main_key {
	local main_keys=${1}
	local version=${2}

	if is_quarterly_release "${version}"
	then
		echo quarterly

		return
	fi

	for main_key in ${main_keys}
	do
		local count=$(echo "${version}" | grep --count --extended-regexp "${main_key}-|${main_key}\.")

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

function get_tag_from_image {
	local image_name="${2}"
	local filter="${3}"
	local version="${1}"

	if [ -z "${version}" ]
	then
		docker pull "${image_name}:latest" >/dev/null

		if [ $? -gt 0 ]
		then
			version="0"
		else
			version=$(docker image inspect --format '{{index .Config.Labels }}' "${image_name}:latest" | grep --only-matching "${filter}" | sed "s/.*://g")
		fi

		echo "${version}"
	else
		echo "${version}"
	fi
}

function has_slim_build_criteria {
	if (is_release_candidate "${1}" || is_u_release "${1}")
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if is_ga_release "${1}"
	then
		if (( "$(get_release_version_trivial "${1}")" <= 132 ))
		then
			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi

	if is_quarterly_release "${1}"
	then
		set_actual_product_version "${1}"

		if is_early_product_version_than "2025.q1.11-lts"
		then
			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_OK}"
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_utils 7z curl docker git java jq sed sort tr unzip yq

	if [[ " ${@} " =~ " --push-all " ]]
	then
		BUILD_ALL_IMAGES_PUSH="push-all"

		if [ "$(git config --global github.user)" == "brianchandotcom" ]
		then
			./release_notes.sh commit

			git push
		fi
	fi

	if [[ " ${@} " =~ " --push " ]]
	then
		BUILD_ALL_IMAGES_PUSH="push"
	fi

	if [ "${BUILD_ALL_IMAGES_PUSH}" == "push" ] ||
	   [ "${BUILD_ALL_IMAGES_PUSH}" == "push-all" ] &&
	   [ -z "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" ]
	then
		LIFERAY_DOCKER_IMAGE_PLATFORMS=linux/amd64,linux/arm64
	fi

	validate_bundles_yml

	make_logs_directory

	build_base_image

	build_jdk_image "JDK 11" "jdk11" "11"
	build_jdk_image "JDK 11 JDK 8" "jdk11-jdk8" "8"
	build_jdk_image "JDK 21 JDK 11 JDK 8" "jdk21-jdk11-jdk8" "21"
	build_jdk_image "JDK 21" "jdk21" "21"

	build_batch_image
	build_caddy_image
	build_jar_runner_image
	build_job_runner_image
	build_node_runner_image
	build_noop_image
	build_squid_image
	#build_zabbix_server_image
	#build_zabbix_web_image

	build_bundle_images

	echo ""
	echo "Results: "
	echo ""

	cat "${LIFERAY_DOCKER_LOGS_DIR}/results"

	if [ $(grep --count "FAILED" "${LIFERAY_DOCKER_LOGS_DIR}/results") != 0 ]
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
	local main_keys=$(yq '' < bundles.yml | grep --invert-match '  .*' | sed "s/://")
	local portal_latest_key_counter=0

	for main_key in ${main_keys}
	do
		if [ $(yq .\""${main_key}"\".*.latest < bundles.yml | grep "true\|false" -c) -gt 0 ]
		then
			local minor_keys=$(yq .\""${main_key}"\" < bundles.yml | grep --invert-match '  .*' | sed "s/://")

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