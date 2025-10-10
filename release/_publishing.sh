#!/bin/bash

source ../_release_common.sh
source ./_git.sh
source ./_releases_json.sh

function add_fixed_issues_to_patcher_project_version {
	lc_download "https://releases.liferay.com/dxp/${_PRODUCT_VERSION}/release-notes.txt" release-notes.txt

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download release-notes.txt."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	IFS=',' read -r -a fixed_issues_array < "release-notes.txt"

	local fixed_issues_array_length="${#fixed_issues_array[@]}"

	local fixed_issues_array_part_length=$((fixed_issues_array_length / 4))

	for counter in {0..3}
	do
		local start_index=$((counter * fixed_issues_array_part_length))

		if [ "${counter}" -eq 3 ]
		then
			fixed_issues_array_part_length=$((fixed_issues_array_length - start_index))
		fi

		IFS=',' fixed_issues="${fixed_issues_array[*]:start_index:fixed_issues_array_part_length}"

		local update_fixed_issues_response=$(curl \
			"https://patcher.liferay.com/api/jsonws/osb-patcher-portlet.project_versions/updateFixedIssues" \
			--data-raw "fixedIssues=${fixed_issues}&patcherProjectVersionId=${1}" \
			--max-time 10 \
			--retry 3 \
			--user "${LIFERAY_RELEASE_PATCHER_PORTAL_EMAIL_ADDRESS}:${LIFERAY_RELEASE_PATCHER_PORTAL_PASSWORD}")

		if [ $(echo "${update_fixed_issues_response}" | jq --raw-output '.status') -eq 200 ]
		then
			lc_log INFO "Adding fixed issues to Liferay Patcher project version ${2}."
		else
			lc_log ERROR "Unable to add fixed issues to Liferay Patcher project ${2}:"

			lc_log ERROR "${update_fixed_issues_response}"

			rm --force release-notes.txt

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done

	lc_log INFO "Added fixed issues to Liferay Patcher project ${2}."

	rm --force release-notes.txt
}

function add_patcher_project_version {
	if [[ "${_PRODUCT_VERSION}" == *ga* ]]
	then
		lc_log INFO "Skipping the add patcher project version step for ${_PRODUCT_VERSION}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local patcher_project_version="$(get_patcher_project_version)"

	local add_by_name_response=$(\
		curl \
			"https://patcher.liferay.com/api/jsonws/osb-patcher-portlet.project_versions/addByName" \
			--data-raw "combinedBranch=true&committish=${patcher_project_version}&fixedIssues=&name=${patcher_project_version}&productVersionLabel=$(get_patcher_product_version_label)&repositoryName=liferay-portal-ee&rootPatcherProjectVersionName=$(get_root_patcher_project_version_name)" \
			--max-time 10 \
			--retry 3 \
			--user "${LIFERAY_RELEASE_PATCHER_PORTAL_EMAIL_ADDRESS}:${LIFERAY_RELEASE_PATCHER_PORTAL_PASSWORD}")

	if [ $(echo "${add_by_name_response}" | jq --raw-output '.status') -eq 200 ]
	then
		lc_log INFO "Added Liferay Patcher project version ${patcher_project_version}."

		add_fixed_issues_to_patcher_project_version $(echo "${add_by_name_response}" | jq --raw-output '.data.patcherProjectVersionId') "${patcher_project_version}"
	else
		lc_log ERROR "Unable to add Liferay Patcher project ${patcher_project_version}:"

		lc_log ERROR "${add_by_name_response}"

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_url {
	local file_url="${1}"

	if (curl \
			"${file_url}" \
			--fail \
			--head \
			--max-time 300 \
			--output /dev/null \
			--retry 3 \
			--retry-delay 10 \
			--silent \
			--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}")
	then
		lc_log DEBUG "File is available at ${file_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	else
		lc_log DEBUG "Unable to access ${file_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_MISSING_RESOURCE}"
	fi
}

function get_patcher_product_version_label {
	if is_7_3_release
	then
		echo "DXP 7.3"
	elif is_7_4_release
	then
		echo "DXP 7.4"
	else
		echo "Quarterly Releases"
	fi
}

function get_patcher_project_version {
	if is_7_3_release
	then
		echo "fix-pack-dxp-$(echo "${_PRODUCT_VERSION}" | cut --delimiter='u' --fields=2)-7310"
	elif is_quarterly_release
	then
		echo "${_ARTIFACT_VERSION}"
	else
		echo "${_PRODUCT_VERSION}"
	fi
}

function get_root_patcher_project_version_name {
	if is_7_3_release
	then
		echo "fix-pack-base-7310"
	elif is_7_4_release
	then
		echo "7.4.13-ga1"
	else
		echo ""
	fi
}

function init_gcs {
	if [ ! -n "${LIFERAY_RELEASE_GCS_TOKEN}" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_GCS_TOKEN."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gcloud auth activate-service-account --key-file "${LIFERAY_RELEASE_GCS_TOKEN}"
}

function remove_old_release_candidate_tags {
	lc_log INFO "Removing old release candidate tags for ${1}."

	local auth_token=$( \
		curl \
			"https://hub.docker.com/v2/users/login/" \
			--data-raw '
				{
					"password": "'"${LIFERAY_DOCKER_HUB_TOKEN}"'",
					"username": "'"${LIFERAY_DOCKER_HUB_USERNAME}"'"
				}' \
			--header "Content-Type: application/json" \
			--silent | \
			jq --raw-output .token)

	if [ "${auth_token}" == "null" ] || [ -z "${auth_token}" ]
	then
		lc_log ERROR "Unable to authenticate on Docker hub."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local tags=$( \
		curl \
			"https://hub.docker.com/v2/repositories/liferay/release-candidates/tags?page_size=80" \
			--header "Authorization: JWT ${auth_token}" \
			--silent | \
			jq --raw-output ".results[].name" | \
			grep "^${1}")

	if [ -z "${tags}" ]
	then
		lc_log INFO "No old release candidate tags for ${1} were found."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	for tag in ${tags}
	do
		curl \
			"https://hub.docker.com/v2/repositories/liferay/release-candidates/tags/${tag}/" \
			--header "Authorization: JWT ${auth_token}" \
			--request DELETE \
			--silent
	done
}

function upload_bom_file {
	local nexus_repository_name="${1}"

	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	local file_path="${2}"

	local file_name="${file_path##*/}"

	local component_name="${file_name/%-*}"


	if [ "${nexus_repository_name}" == "liferay-public-releases" ]
	then
		local file_url="${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${component_name}/${_ARTIFACT_VERSION}/${file_name}"
	else
		local file_url="${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${component_name}/${_ARTIFACT_RC_VERSION}/${file_name}"
	fi

	_upload_to_nexus "${file_path}" "${file_url}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_upload_to_nexus "${file_path}.MD5" "${file_url}.md5" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_upload_to_nexus "${file_path}.sha512" "${file_url}.sha512" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function upload_boms {
	local nexus_repository_name="${1}"

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ] && [ "${nexus_repository_name}" == "xanadu" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" ] || [ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}" ]
	then
		 lc_log ERROR "Either \${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD} or \${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER} is undefined."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ "${nexus_repository_name}" == "liferay-public-releases" ]
	then
		local upload_dir="${_PROMOTION_DIR}"
	else
		local upload_dir="${_BUILD_DIR}/release"
	fi

	find "${upload_dir}" -regextype egrep -regex '.*/*.(jar|pom)' -print0 | while IFS= read -r -d '' file_path
	do
		upload_bom_file "${nexus_repository_name}" "${file_path}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	done
}

function upload_hotfix {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if (has_ssh_connection "lrdcom-vm-1")
	then
		lc_log INFO "Connecting to lrdcom-vm-1."

		ssh root@lrdcom-vm-1 mkdir --parents "/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/"

		#
		# shellcheck disable=SC2029
		#

		if (ssh root@lrdcom-vm-1 ls "/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/" | grep --quiet "${_HOTFIX_FILE_NAME}")
		then
			lc_log INFO "Skipping the upload of ${_HOTFIX_FILE_NAME} to lrdcom-vm-1 because it already exists."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		scp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/"

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to upload ${_HOTFIX_FILE_NAME} to lrdcom-vm-1."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		lc_log INFO "${_HOTFIX_FILE_NAME} successfully uploaded to lrdcom-vm-1."
	fi

	for gcp_bucket in liferay-releases/dxp/hotfix liferay-releases-hotfix
	do
		if (gsutil ls "gs://${gcp_bucket}/${_PRODUCT_VERSION}" | grep --quiet "${_HOTFIX_FILE_NAME}")
		then
			lc_log INFO "Skipping the upload of ${_HOTFIX_FILE_NAME} to GCP bucket ${gcp_bucket} because it already exists."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		gsutil cp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" "gs://${gcp_bucket}/${_PRODUCT_VERSION}/"

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to upload ${_HOTFIX_FILE_NAME} to GCP bucket ${gcp_bucket}."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		lc_log INFO "${_HOTFIX_FILE_NAME} successfully uploaded to GCP bucket ${gcp_bucket}."
	done
}

function upload_opensearch {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		rm --force "${_BUNDLES_DIR}/osgi/portal/com.liferay.portal.search.opensearch2.api.jar"
		rm --force "${_BUNDLES_DIR}/osgi/portal/com.liferay.portal.search.opensearch2.impl.jar"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local release_dir_name="${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}"

	if [ "$(get_release_output)" == "nightly" ]
	then
		release_dir_name="nightly"
	fi

	for module in api impl
	do
		gsutil mv \
			"${_BUNDLES_DIR}/osgi/portal/com.liferay.portal.search.opensearch2.${module}.jar" \
			"gs://liferay-releases/opensearch2/${release_dir_name}/com.liferay.portal.search.opensearch2.${component}.jar"

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to upload com.liferay.portal.search.opensearch2.${module}.jar."
	
			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done
}

function upload_release {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}"/release

	local ssh_connection="false"

	if (has_ssh_connection "lrdcom-vm-1")
	then
		lc_log INFO "Connecting to lrdcom-vm-1."

		ssh_connection="true"

		if [ "$(get_release_output)" == "nightly" ]
		then
			ssh root@lrdcom-vm-1 rm --recursive "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/nightly/*"
		else
			ssh root@lrdcom-vm-1 rm --recursive "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-*"

			ssh root@lrdcom-vm-1 mkdir --parents "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"
		fi

	else
		lc_log INFO "Skipping lrdcom-vm-1."
	fi

	local destination_bucket=""
	local destination_dir=""

	if [ "$(get_release_output)" == "nightly" ]
	then
		gsutil rm -r "gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}/nightly/"

		destination_bucket="gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}/nightly/"
		destination_dir="/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/nightly"
	else
		gsutil rm -r "gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-*"

		destination_bucket="gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/"
		destination_dir="/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"
	fi

	for file in $(ls --almost-all --ignore "*.jar*" --ignore "*.pom*")
	do
		if [ -f "${file}" ]
		then
			echo "Copying ${file}."

			gsutil cp "${_BUILD_DIR}/release/${file}" "${destination_bucket}"

			if [ "${ssh_connection}" == "true" ]
			then
				scp "${file}" root@lrdcom-vm-1:"${destination_dir}"
			fi
		fi
	done
}

function upload_to_docker_hub {
	if [ "$(get_release_output)" == "release-candidate" ] &&
	   [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BASE_DIR}"

	if [ "$(get_release_output)" == "release-candidate" ]
	then
		LIFERAY_DOCKER_IMAGE_FILTER="${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}" LIFERAY_DOCKER_RELEASE_CANDIDATE="true" ./build_all_images.sh --push
	elif [ "$(get_release_output)" == "nightly" ]
	then
		LIFERAY_DOCKER_IMAGE_FILTER="7.4.13.nightly" LIFERAY_DOCKER_RELEASE_CANDIDATE="false" ./build_all_images.sh --push
	else
		prepare_branch_to_commit "${_BASE_DIR}" "liferay-docker"

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to prepare the branch to update bundles.yml."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		_update_bundles_yml

		LIFERAY_DOCKER_IMAGE_FILTER="${_PRODUCT_VERSION}" LIFERAY_DOCKER_RELEASE_CANDIDATE="false" ./build_all_images.sh --push-all
	fi

	local exit_code="${?}"

	if [ "${exit_code}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to build the Docker image."
	fi

	if [ "$(get_release_output)" == "release" ]
	then
		remove_old_release_candidate_tags "${_PRODUCT_VERSION}"
	fi

	lc_cd "${_RELEASE_ROOT_DIR}"

	return "${exit_code}"
}

function _update_bundles_yml {
	local product_version_key="$(echo "${_PRODUCT_VERSION}" | cut --delimiter='-' --fields=1)"

	if (yq eval ".\"${product_version_key}\" | has(\"${_PRODUCT_VERSION}\")" "${_BASE_DIR}/bundles.yml" | grep --quiet "true") ||
	   (yq eval ".quarterly | has(\"${_PRODUCT_VERSION}\")" "${_BASE_DIR}/bundles.yml" | grep --quiet "true")
	then
		lc_log INFO "The ${_PRODUCT_VERSION} product version was already published."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if is_quarterly_release
	then
		if [ "$(get_latest_product_version "quarterly")" == "${_PRODUCT_VERSION}" ]
		then
			local latest_quarterly_release_key=$(yq eval ".quarterly | keys | .[-1]" "${_BASE_DIR}/bundles.yml")

			yq --indent 4 --inplace eval "del(.quarterly.\"${latest_quarterly_release_key}\".latest)" "${_BASE_DIR}/bundles.yml"
			yq --indent 4 --inplace eval ".quarterly.\"${_PRODUCT_VERSION}\".latest = true" "${_BASE_DIR}/bundles.yml"
		else
			local previous_quarterly_release_key=$(\
				yq ".quarterly" "${_BASE_DIR}/bundles.yml" | \
				grep "$(get_product_group_version)" | \
				tail --lines=1)

			sed --in-place "/${previous_quarterly_release_key}/a\    ${_PRODUCT_VERSION}:" "${_BASE_DIR}/bundles.yml"
		fi
	fi

	if is_7_3_release
	then
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\" = {}" "${_BASE_DIR}/bundles.yml"
	fi

	if is_7_4_u_release
	then
		local nightly_bundle_url=$(yq eval ".\"${product_version_key}\".\"${product_version_key}.nightly\".bundle_url" "${_BASE_DIR}/bundles.yml")

		yq --indent 4 --inplace eval "del(.\"${product_version_key}\".\"${product_version_key}.nightly\")" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\" = {}" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${product_version_key}.nightly\".bundle_url = \"${nightly_bundle_url}\"" "${_BASE_DIR}/bundles.yml"
	fi

	if is_7_4_ga_release
	then
		local ga_bundle_url="releases-cdn.liferay.com/portal/${_PRODUCT_VERSION}/"$(curl --fail --location --show-error --silent "https://releases-cdn.liferay.com/portal/${_PRODUCT_VERSION}/.lfrrelease-tomcat-bundle")

		perl -i -0777pe 's/\s+latest: true(?!7.4.13:)//' "${_BASE_DIR}/bundles.yml"

		sed --in-place "/7.4.13:/i ${product_version_key}:" "${_BASE_DIR}/bundles.yml"

		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\".bundle_url = \"${ga_bundle_url}\"" "${_BASE_DIR}/bundles.yml"
		yq --indent 4 --inplace eval ".\"${product_version_key}\".\"${_PRODUCT_VERSION}\".latest = true" "${_BASE_DIR}/bundles.yml"
	fi

	sed --in-place "/^$/d" "${_BASE_DIR}/bundles.yml"
	sed --in-place "s/[[:space:]]{}//g" "${_BASE_DIR}/bundles.yml"

	if [ -z "$(tail --bytes=1 "${_BASE_DIR}/bundles.yml")" ]
	then
		truncate --size=-1 "${_BASE_DIR}/bundles.yml"
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		commit_to_branch_and_send_pull_request \
			"${_BASE_DIR}/bundles.yml" \
			"Add ${_PRODUCT_VERSION} to bundles.yml." \
			"master" \
			"brianchandotcom/liferay-docker" \
			"Add ${_PRODUCT_VERSION} to bundles.yml."

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			lc_log ERROR "Unable to send pull request to brianchandotcom/liferay-docker."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		else
			lc_log INFO "The pull request was sent successfully."
		fi
	fi
}

function _upload_to_nexus {
	local file_path="${1}"
	local file_url="${2}"

	lc_log INFO "Uploading ${file_path} to ${file_url}."

	if (check_url "${file_url}")
	then
		lc_log "Skipping the upload of ${file_path} to ${file_url} because it already exists."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log INFO "Uploading ${file_path} to ${file_url}."

		curl \
			--fail \
			--max-time 300 \
			--retry 3 \
			--retry-delay 10 \
			--silent \
			--upload-file "${file_path}" \
			--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" \
			"${file_url}"
	fi
}