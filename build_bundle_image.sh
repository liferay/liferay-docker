#!/bin/bash

source ./_common.sh
source ./_liferay_common.sh
source ./_release_common.sh

function build_docker_image {
	if [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL%} == */snapshot-* ]]
	then
		DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME}-snapshot
	fi

	if [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL} == https://release-* ]] || [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL} == *release.liferay.com* ]]
	then
		DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME}-snapshot
	fi

	local release_version=${LIFERAY_DOCKER_RELEASE_FILE_URL%/*}

	release_version=${release_version##*/}

	if [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL} == https://release-* ]] || [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL} == *release.liferay.com* ]]
	then
		release_version=${LIFERAY_DOCKER_RELEASE_FILE_URL#*tomcat-}
		release_version=${release_version%.*}
	fi

	if [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL} == *files.liferay.com/* ]] && [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL%} != */snapshot-* ]]
	then
		local file_name_release_version=${LIFERAY_DOCKER_RELEASE_FILE_URL#*tomcat-}

		file_name_release_version=${file_name_release_version%.*}
		file_name_release_version=${file_name_release_version%-*}

		if [[ ${file_name_release_version} == *-slim ]]
		then
			file_name_release_version=${file_name_release_version%-slim}
		fi

		local service_pack_name=${file_name_release_version##*-}
	fi

	if [[ ${service_pack_name} == ga* ]] || [[ ${service_pack_name} == sp* ]]
	then
		release_version=${release_version}-${service_pack_name}
	fi

	LABEL_VERSION=${release_version}

	if [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL%} == */snapshot-* ]]
	then
		local release_branch=${LIFERAY_DOCKER_RELEASE_FILE_URL%/*}

		release_branch=${release_branch%/*}
		release_branch=${release_branch%-private*}
		release_branch=${release_branch##*-}

		local release_hash=$(cat "${TEMP_DIR}/liferay/.githash")

		release_hash=${release_hash:0:7}

		if [[ ${release_branch} == master ]]
		then
			LABEL_VERSION="Master Snapshot on ${LABEL_VERSION} at ${release_hash}"
		else
			LABEL_VERSION="${release_branch} Snapshot on ${LABEL_VERSION} at ${release_hash}"
		fi
	fi

	if [ -n "${LIFERAY_DOCKER_RELEASE_VERSION}" ]
	then
		release_version=${LIFERAY_DOCKER_RELEASE_VERSION}

		if [ "${LIFERAY_DOCKER_SLIM}" == "true" ]
		then
			release_version=${release_version}-slim
		fi
	fi

	DOCKER_IMAGE_TAGS=()

	local default_ifs=${IFS}

	IFS=","

	for release_version_single in ${release_version}
	do
		if [[ ${LIFERAY_DOCKER_RELEASE_FILE_URL%} == */snapshot-* ]]
		then
			DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${release_branch}-${release_version_single}-${release_hash}")
			DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${release_branch}-$(date "${CURRENT_DATE}" "+%Y%m%d")")
			DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${release_branch}")
		else
			DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${release_version_single}-d$(./release_notes.sh get-version)-${TIMESTAMP}")
			DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${release_version_single}")
		fi
	done

	if [[ "${LIFERAY_DOCKER_LATEST}" = "true" ]]
	then
		DOCKER_IMAGE_TAGS+=("${LIFERAY_DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:latest")
	fi

	if [ -e "${TEMP_DIR}/liferay/.githash" ]
	then
		LIFERAY_VCS_REF=$(cat "${TEMP_DIR}/liferay/.githash")
	fi

	IFS=${default_ifs}

	remove_temp_dockerfile_target_platform

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
		--build-arg LABEL_LIFERAY_PATCHING_TOOL_VERSION="${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}" \
		--build-arg LABEL_LIFERAY_RELEASE_VERSION="${LIFERAY_DOCKER_RELEASE_VERSION}" \
		--build-arg LABEL_LIFERAY_SLIM="${LIFERAY_DOCKER_SLIM}" \
		--build-arg LABEL_LIFERAY_TOMCAT_VERSION=$(get_tomcat_version "${TEMP_DIR}/liferay") \
		--build-arg LABEL_LIFERAY_VCS_REF="${LIFERAY_VCS_REF}" \
		--build-arg LABEL_NAME="${DOCKER_LABEL_NAME}" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
		--build-arg LABEL_VERSION="${LABEL_VERSION}" \
		$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
		"${TEMP_DIR}" || exit 1
}

function check_release {
	if [[ ${RELEASE_FILE_NAME} == *-dxp-* ]] || [[ ${RELEASE_FILE_NAME} == *-private* ]]
	then
		DOCKER_IMAGE_NAME="dxp"
		DOCKER_LABEL_NAME="Liferay DXP"
	elif [[ ${RELEASE_FILE_NAME} == *-portal-* ]]
	then
		DOCKER_IMAGE_NAME="portal"
		DOCKER_LABEL_NAME="Liferay Portal"
	else
		echo "${RELEASE_FILE_NAME} is an unsupported release file name."

		exit 1
	fi
}

function check_usage {
	if [ ! -n "${LIFERAY_DOCKER_RELEASE_FILE_URL}" ]
	then
		print_help
	fi

	check_utils 7z curl docker java unzip
}

function download_file_from_github {
	local file_name=${1}
	local file_path=${2}
	local repository_name=${3}

	local http_response=$(\
		curl \
			"https://api.github.com/repos/liferay/${repository_name}/contents/${file_path}?ref=master" \
			--header "Accept: application/vnd.github.v3.raw" \
			--header "Authorization: token ${LIFERAY_RELEASE_GITHUB_PAT}" \
			--include \
			--max-time 10 \
			--output "${file_name}" \
			--request GET \
			--retry 3 \
			--write-out "%{http_code}")

	if [ "${http_response}" != "200" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function download_trial_dxp_license {
	if [[ ${DOCKER_IMAGE_NAME} == "dxp" ]]
	then
		rm -fr "${TEMP_DIR}/liferay/data/license"

		if (! ./download_trial_dxp_license.sh "${TEMP_DIR}/liferay" $(date "${CURRENT_DATE}" "+%s000"))
		then
			exit 4
		fi
	fi
}

function get_latest_tomcat_version {
	local latest_tomcat_version="9.0.104"

	latest_tomcat_version=$(\
		echo -e "${latest_tomcat_version}\n${1}" | \
		sort --version-sort | \
		tail -1)

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		download_file_from_github \
			"app.server.properties" \
			"app.server.properties" \
			"liferay-portal-ee"
	fi

	if [ "${?}" == "${LIFERAY_COMMON_EXIT_CODE_OK}" ]
	then
		local master_tomcat_version=$(lc_get_property "app.server.properties" "app.server.tomcat.version")

		rm -f "app.server.properties"

		latest_tomcat_version=$(\
			echo -e "${latest_tomcat_version}\n${master_tomcat_version}" | \
			sort --version-sort | \
			tail -1)
	fi

	echo "${latest_tomcat_version}"
}

function install_fix_pack {
	if [ -n "${LIFERAY_DOCKER_FIX_PACK_URL}" ]
	then
		local fix_pack_url=${LIFERAY_DOCKER_FIX_PACK_URL}

		FIX_PACK_FILE_NAME=${fix_pack_url##*/}

		download downloads/fix-packs/"${FIX_PACK_FILE_NAME}" "${fix_pack_url}"

		cp "downloads/fix-packs/${FIX_PACK_FILE_NAME}" "${TEMP_DIR}/liferay/patching-tool/patches"

		"${TEMP_DIR}/liferay/patching-tool/patching-tool.sh" install

		rm -fr "${TEMP_DIR}/liferay/data/hypersonic/"*
		rm -fr "${TEMP_DIR}/liferay/osgi/state/"*
	fi
}

function main {
	if [[ " ${@} " =~ " --test " ]]
	then
		return
	fi

	check_usage "${@}"

	make_temp_directory templates/bundle

	set_parent_image

	prepare_temp_directory "${@}"

	check_release "${@}"

	update_patching_tool

	install_fix_pack "${@}"

	prepare_tomcat

	if [ "${LIFERAY_DOCKER_SLIM}" == "true" ]
	then
		prepare_slim_image

		if [ "${?}" -ne 0 ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi

	download_trial_dxp_license

	build_docker_image

	test_docker_image

	log_in_to_docker_hub

	push_docker_image "${1}"

	clean_up_temp_directory
}

function prepare_slim_image {
	rm -fr "${TEMP_DIR}/liferay/elasticsearch-sidecar"

	local product_name=$(echo "${LIFERAY_DOCKER_RELEASE_FILE_URL}" | cut -d '/' -f 2)
	local product_version=$(echo "${LIFERAY_DOCKER_RELEASE_FILE_URL}" | cut -d '/' -f 3)

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases-gcp.liferay.com/opensearch2/${product_name}/${product_version}/com.liferay.portal.search.opensearch2.api.jar" "${TEMP_DIR}/liferay/deploy/com.liferay.portal.search.opensearch2.api.jar"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download com.liferay.portal.search.opensearch2.api.jar."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases-gcp.liferay.com/opensearch2/${product_name}/${product_version}/com.liferay.portal.search.opensearch2.impl.jar" "${TEMP_DIR}/liferay/deploy/com.liferay.portal.search.opensearch2.impl.jar"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download com.liferay.portal.search.opensearch2.impl.jar."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function prepare_temp_directory {
	RELEASE_FILE_NAME=${LIFERAY_DOCKER_RELEASE_FILE_URL##*/}

	local download_dir=${LIFERAY_DOCKER_RELEASE_FILE_URL%/*}

	download_dir=${download_dir#*com/}
	download_dir=${download_dir#*com/}
	download_dir=${download_dir#*liferay-release-tool/}
	download_dir=${download_dir#*private/ee/}
	download_dir=downloads/${download_dir}

	download "${download_dir}/${RELEASE_FILE_NAME}" "${LIFERAY_DOCKER_RELEASE_FILE_URL}"

	if [[ ${RELEASE_FILE_NAME} == *.7z ]]
	then
		7z x -O"${TEMP_DIR}" "${download_dir}/${RELEASE_FILE_NAME}" || exit 3
	else
		unzip -d "${TEMP_DIR}" -q "${download_dir}/${RELEASE_FILE_NAME}"  || exit 3
	fi

	mv "${TEMP_DIR}/liferay-"* "${TEMP_DIR}/liferay"

	local tomcat_version=$(get_tomcat_version "${TEMP_DIR}/liferay")

	local latest_tomcat_version=$(get_latest_tomcat_version "${tomcat_version}")

	if [ "${tomcat_version}" != "${latest_tomcat_version}" ]
	then
		local latest_tomcat_dir_name="tomcat"
		local tomcat_dir_name="tomcat"

		if [ ! -e "${TEMP_DIR}/liferay/tomcat" ]
		then
			latest_tomcat_dir_name="tomcat-${latest_tomcat_version}"
			tomcat_dir_name="tomcat-${tomcat_version}"
		fi

		mv "${TEMP_DIR}/liferay/${tomcat_dir_name}" "${TEMP_DIR}/liferay/tomcat-temp"

		local latest_tomcat_download_dir="downloads/tomcat/apache-tomcat-${latest_tomcat_version}"

		local latest_tomcat_major_version=$(echo "${latest_tomcat_version}" | cut -d '.' -f 1)

		local latest_tomcat_url="https://dlcdn.apache.org/tomcat/tomcat-${latest_tomcat_major_version}/v${latest_tomcat_version}/bin/apache-tomcat-${latest_tomcat_version}.zip"

		download "${latest_tomcat_download_dir}/apache-tomcat.zip" "${latest_tomcat_url}"

		unzip -d "${TEMP_DIR}/liferay" -q "${latest_tomcat_download_dir}/apache-tomcat.zip" || exit 3

		mv "${TEMP_DIR}/liferay/apache-tomcat-"* "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}"

		rm -fr "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/conf"
		rm -fr "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/temp/safeToDelete.tmp"
		rm -fr "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/webapps"

		cp -r "${TEMP_DIR}/liferay/tomcat-temp/LICENSE" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/LICENSE"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/NOTICE" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/NOTICE"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/RELEASE-NOTES" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/RELEASE-NOTES"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/bin/catalina-tasks.xml" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/bin/catalina-tasks.xml"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/bin/setenv.bat" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/bin/setenv.bat"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/bin/setenv.sh" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/bin/setenv.sh"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/conf" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/"

		if is_7_3_release
		then
			cp -r "${TEMP_DIR}/liferay/tomcat-temp/lib/ext" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/lib/ext"
		fi

		cp -r "${TEMP_DIR}/liferay/tomcat-temp/webapps" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/"
		cp -r "${TEMP_DIR}/liferay/tomcat-temp/work/Catalina" "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/work/Catalina"

		rm -fr "${TEMP_DIR}/liferay/tomcat-temp"

		chmod +x "${TEMP_DIR}/liferay/${latest_tomcat_dir_name}/bin/"*
	fi
}

function print_help {
	echo "Usage: ${0} --push"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_DOCKER_DEVELOPER_MODE (optional): If set to \"true\", all local images will be deleted before building a new one"
	echo "    LIFERAY_DOCKER_FIX_PACK_URL (optional): URL to a fix pack"
	echo "    LIFERAY_DOCKER_HUB_TOKEN (optional): Docker Hub token to log in automatically"
	echo "    LIFERAY_DOCKER_HUB_USERNAME (optional): Docker Hub username to log in automatically"
	echo "    LIFERAY_DOCKER_IMAGE_PLATFORMS (optional): Comma separated Docker image platforms to build when the \"push\" parameter is set"
	echo "    LIFERAY_DOCKER_LICENSE_API_HEADER (required for DXP): API header used to generate the trial license"
	echo "    LIFERAY_DOCKER_LICENSE_API_URL (required for DXP): API URL to generate the trial license"
	echo "    LIFERAY_DOCKER_RELEASE_FILE_URL (required): URL to a Liferay bundle"
	echo "    LIFERAY_DOCKER_REPOSITORY (optional): Docker repository"
	echo "    LIFERAY_DOCKER_SLIM (optional): If set to \"true\", the image will be smaller"
	echo ""
	echo "Example: LIFERAY_DOCKER_RELEASE_FILE_URL=files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z ${0} push"
	echo ""
	echo "Set \"push\" as a parameter to automatically push the image to Docker Hub."

	exit 1
}

function push_docker_image {
	if [ "${1}" == "push" ]
	then
		check_docker_buildx

		sed -i '1s/FROM /FROM --platform=${TARGETPLATFORM} /g' "${TEMP_DIR}"/Dockerfile

		docker buildx build \
			--build-arg LABEL_BUILD_DATE=$(date "${CURRENT_DATE}" "+%Y-%m-%dT%H:%M:%SZ") \
			--build-arg LABEL_LIFERAY_PATCHING_TOOL_VERSION="${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}" \
			--build-arg LABEL_LIFERAY_RELEASE_VERSION="${LIFERAY_DOCKER_RELEASE_VERSION}" \
			--build-arg LABEL_LIFERAY_SLIM="${LIFERAY_DOCKER_SLIM}" \
			--build-arg LABEL_LIFERAY_TOMCAT_VERSION=$(get_tomcat_version "${TEMP_DIR}/liferay") \
			--build-arg LABEL_LIFERAY_VCS_REF="${LIFERAY_VCS_REF}" \
			--build-arg LABEL_NAME="${DOCKER_LABEL_NAME}" \
			--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
			--build-arg LABEL_VCS_URL="https://github.com/liferay/liferay-docker" \
			--build-arg LABEL_VERSION="${LABEL_VERSION}" \
			--builder "liferay-buildkit" \
			--platform "${LIFERAY_DOCKER_IMAGE_PLATFORMS}" \
			--push \
			$(get_docker_image_tags_args "${DOCKER_IMAGE_TAGS[@]}") \
			"${TEMP_DIR}" || exit 1
	fi
}

function set_parent_image {
	if is_quarterly_release "${LIFERAY_DOCKER_RELEASE_VERSION}"
	then
		local release_year="$(get_release_year "${LIFERAY_DOCKER_RELEASE_VERSION}")"

		if [[ "${release_year}" -gt 2024 ]]
		then
			return
		fi

		if [[ "${release_year}" -eq 2024 ]] &&
		   [[ "$(get_release_quarter "${LIFERAY_DOCKER_RELEASE_VERSION}")" -ge 3 ]]
		then
			return
		fi

		sed -i 's/liferay\/jdk21:latest AS liferay-jdk21/liferay\/jdk11:latest AS liferay-jdk11/g' "${TEMP_DIR}"/Dockerfile
		sed -i 's/FROM liferay-jdk21/FROM liferay-jdk11/g' "${TEMP_DIR}"/Dockerfile
	elif [ "$(get_product_group_version "${LIFERAY_DOCKER_RELEASE_VERSION}")" == "7.4" ]
	then
		if is_nightly_release "${LIFERAY_DOCKER_RELEASE_VERSION}"
		then
			return
		fi

		if [ "$(get_release_version "${LIFERAY_DOCKER_RELEASE_VERSION}")" == "7.4.13" ] &&
		   [[ "$(get_release_version_trivial "${LIFERAY_DOCKER_RELEASE_VERSION}")" -ge 125 ]]
		then
			return
		fi

		if [ "$(get_release_version "${LIFERAY_DOCKER_RELEASE_VERSION}")" == "7.4.3" ] &&
		   [[ "$(get_release_version_trivial "${LIFERAY_DOCKER_RELEASE_VERSION}")" -ge 125 ]]
		then
			return
		fi

		sed -i 's/liferay\/jdk21:latest AS liferay-jdk21/liferay\/jdk11:latest AS liferay-jdk11/g' "${TEMP_DIR}"/Dockerfile
		sed -i 's/FROM liferay-jdk21/FROM liferay-jdk11/g' "${TEMP_DIR}"/Dockerfile
	elif [[ "$(get_product_group_version "${LIFERAY_DOCKER_RELEASE_VERSION}" | tr -d .)" -le 73 ]]
	then
		sed -i 's/liferay\/jdk21:latest AS liferay-jdk21/liferay\/jdk11-jdk8:latest AS liferay-jdk11-jdk8/g' "${TEMP_DIR}"/Dockerfile
		sed -i 's/FROM liferay-jdk21/FROM liferay-jdk11-jdk8/g' "${TEMP_DIR}"/Dockerfile
	fi
}

function update_patching_tool {
	if [ -e "${TEMP_DIR}/liferay/tomcat" ]
	then
		sed -i "s@tomcat-[0-9]*.[0-9]*.[0-9]*/@tomcat/@g" "${TEMP_DIR}/liferay/patching-tool/default.properties"
	fi

	if [ -e "${TEMP_DIR}/liferay/patching-tool" ]
	then
		local patching_tool_minor_version=$("${TEMP_DIR}"/liferay/patching-tool/patching-tool.sh version | grep "Patching-tool version")

		if [ ! -n "${patching_tool_minor_version}" ]
		then
			patching_tool_minor_version="2.0.0"
		else
			patching_tool_minor_version=${patching_tool_minor_version##*Patching-tool version: }
		fi

		patching_tool_minor_version=${patching_tool_minor_version%.*}

		if (! echo ${patching_tool_minor_version} | grep -e '[0-9]*[.][0-9]*' >/dev/null)
		then
			echo "Patching Tool update is skipped as it's not a 1.0+ version or the bundle did not include a properly configured Patching Tool."

			return
		fi

		mv "${TEMP_DIR}/liferay/patching-tool/patches" "${TEMP_DIR}/liferay/patching-tool-upgrade-patches"

		rm -fr "${TEMP_DIR}/liferay/patching-tool"

		local latest_patching_tool_version

		#
		# Set the latest patching tool version in a separate line to get the
		# proper exit code.
		#

		latest_patching_tool_version=$(./patching_tool_version.sh ${patching_tool_minor_version})

		local exit_code=$?

		if [ ${exit_code} -gt 0 ]
		then
			echo "./patching_tool_version.sh returned with an error: ${latest_patching_tool_version}"

			exit ${exit_code}
		fi

		echo ""
		echo "Updating Patching Tool to version ${latest_patching_tool_version}."
		echo ""

		download "downloads/patching-tool/patching-tool-${latest_patching_tool_version}.zip" "releases-cdn.liferay.com/tools/patching-tool/patching-tool-${latest_patching_tool_version}.zip"

		unzip -d "${TEMP_DIR}/liferay" -q "downloads/patching-tool/patching-tool-${latest_patching_tool_version}.zip"

		"${TEMP_DIR}/liferay/patching-tool/patching-tool.sh" auto-discovery

		rm -fr "${TEMP_DIR}/liferay/patching-tool/patches"

		mv "${TEMP_DIR}/liferay/patching-tool-upgrade-patches" "${TEMP_DIR}/liferay/patching-tool/patches"

		if [ ! -n "${LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION}" ]
		then
			export LIFERAY_DOCKER_TEST_PATCHING_TOOL_VERSION="${latest_patching_tool_version}"
		fi
	fi
}

main "${@}"