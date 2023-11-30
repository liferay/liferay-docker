#!/bin/bash

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
	local file_path="${2}"

	local file_name="${file_path##*/}"
	local directory_name="${file_name/%-*}"

	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	_upload_to_nexus "${file_path}" "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${directory_name}/${_DXP_VERSION}/${file_name}"

	_upload_to_nexus "${file_path}.MD5" "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${directory_name}/${_DXP_VERSION}/${file_name}.md5"

	_upload_to_nexus "${file_path}.sha512" "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${directory_name}/${_DXP_VERSION}/${file_name}.sha512"
}

function upload_boms {
	local nexus_repository_name="${1}"

	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	find "${_BUILD_DIR}/release" -regextype egrep -regex '.*/*.(jar|pom)' -print0 | while IFS= read -r -d '' file_path
	do
		upload_bom_file "${nexus_repository_name}" "${file_path}"
	done
}

function upload_hotfix {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/"

	# shellcheck disable=SC2029
	if (ssh root@lrdcom-vm-1 ls "/www/releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/" | grep -q "${_HOTFIX_FILE_NAME}")
	then
		lc_log ERROR "Skipping the upload of ${_HOTFIX_FILE_NAME} because it already exists."

		return 1
	fi

	scp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/"

	echo "# Uploaded" > ../output.md
	echo " - https://releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/${_HOTFIX_FILE_NAME}" >> ../output.md

	#gsutil cp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" "gs://patcher-storage/hotfix/${_DXP_VERSION}/"
}

function upload_release {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_UPLOAD to \"true\" to enable."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}"/release

	echo "# Uploaded" > ../output.md

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/dxp/release-candidates/${_DXP_VERSION}-${_BUILD_TIMESTAMP}"

	for file in * .*
	do
		if [ -f "${file}" ]
		then
			echo "Copying ${file}."

			#gsutil cp "${_BUILD_DIR}/release/${file}" "gs://patcher-storage/dxp/${_DXP_VERSION}/"

			scp "${file}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/release-candidates/${_DXP_VERSION}-${_BUILD_TIMESTAMP}"

			echo " - https://releases.liferay.com/dxp/release-candidates/${_DXP_VERSION}-${_BUILD_TIMESTAMP}/${file}" >> ../output.md
		fi
	done
}

function _upload_to_nexus {
	local file_path="${1}"
	local file_url="${2}"

	if [ -z "${NEXUS_REPOSITORY_USER}" ] || [ -z "${NEXUS_REPOSITORY_PASSWORD}" ]
	then
		 lc_log ERROR "Either \${NEXUS_REPOSITORY_USER} or \${NEXUS_REPOSITORY_PASSWORD} is undefined."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_log INFO "Uploading ${file_path} to ${file_url}."

	curl \
		--fail \
		--max-time 300 \
		--retry 3 \
		--retry-delay 10 \
		--silent \
		-u "${NEXUS_REPOSITORY_USER}:${NEXUS_REPOSITORY_PASSWORD}" \
		--upload-file "${file_path}" \
		"${file_url}"
}