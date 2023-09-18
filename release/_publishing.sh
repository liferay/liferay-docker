#!/bin/bash

function init_gcs {
	if [ ! -e /opt/liferay/patcher-storage-service-account.json ]
	then
		lc_log INFO "/opt/liferay/patcher-storage-service-account.json does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gcloud auth activate-service-account --key-file /opt/liferay/patcher-storage-service-account.json
}

function upload_release {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "The environment variable LIFERAY_RELEASE_UPLOAD was not set to \"true\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}"/release/

	echo "# Uploaded files" > ../release.md

	for file in *
	do
		if [ -f "${file}" ]
		then
			gsutil cp "${_BUILD_DIR}/release/${file}" "gs://patcher-storage/dxp/${_DXP_VERSION}/"

			echo " - https://storage.googleapis.com/patcher-storage/dxp/${_DXP_VERSION}/${file}" >> ../release.md
		fi
	done
}

function upload_hotfix {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "The environment variable LIFERAY_RELEASE_UPLOAD was not set to \"true\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gsutil cp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" "gs://patcher-storage/hotfix/${_DXP_VERSION}/"
}