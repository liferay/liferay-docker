#!/bin/bash

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

function init_gcs {
	if [ ! -n "${LIFERAY_RELEASE_GCS_TOKEN}" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_GCS_TOKEN."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gcloud auth activate-service-account --key-file "${LIFERAY_RELEASE_GCS_TOKEN}"
}

function upload_bom_file {
	local nexus_repository_name="${1}"

	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	local file_path="${2}"

	local file_name="${file_path##*/}"

	local component_name="${file_name/%-*}"


	if [ "${nexus_repository_name}" == "liferay-public-releases" ]
	then
		local file_url="${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${component_name}/${_PRODUCT_VERSION}/${file_name}"
	else
		local file_url="${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${component_name}/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/${file_name}"
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

	ssh root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/"

	#
	# shellcheck disable=SC2029
	#

	if (ssh root@lrdcom-vm-1 ls "/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/" | grep -q "${_HOTFIX_FILE_NAME}")
	then
		lc_log ERROR "Skipping the upload of ${_HOTFIX_FILE_NAME} because it already exists."

		return 1
	fi

	scp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/"

	if (gsutils ls "gs://liferay-releases-hotfix/${_PRODUCT_VERSION}" | grep -q "${_HOTFIX_FILE_NAME}")
	then
		lc_log ERROR "Skipping the upload of ${_HOTFIX_FILE_NAME} to GCP because it already exists."

		return 1
	fi

	gsutil cp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" "gs://liferay-releases-hotfix/${_PRODUCT_VERSION}"

	echo "# Uploaded" > ../output.md
	echo " - https://releases.liferay.com/dxp/hotfix/${_PRODUCT_VERSION}/${_HOTFIX_FILE_NAME}" >> ../output.md
}

function upload_release {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}"/release

	echo "# Uploaded" > ../output.md

	ssh root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"

	for file in * .*
	do
		if [ -f "${file}" ]
		then
			echo "Copying ${file}."

			gsutil cp "${_BUILD_DIR}/release/${file}" "gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}"

			scp "${file}" root@lrdcom-vm-1:"/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"

			echo " - https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/${file}" >> ../output.md
		fi
	done
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