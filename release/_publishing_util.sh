#!/bin/bash

function init_gcs {
	if [ ! -e /opt/liferay/patcher-storage-service-account.json ]
	then
		echo "/opt/liferay/patcher-storage-service-account.json does not exist, skipping init_gcs"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gcloud auth activate-service-account --key-file /opt/liferay/patcher-storage-service-account.json
}

function upload_bundle {
	if [ ! -n "${LIFERAY_RELEASE_UPLOAD}" ]
	then
		echo "Skipping upload_bundle as LIFERAY_RELEASE_UPLOAD is not set."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gsutil cp "${_BUILD_DIR}"/release/* "gs://patcher-storage/dxp/${DXP_VERSION}/"
}

function upload_hotfix {
	if [ ! -n "${LIFERAY_RELEASE_UPLOAD}" ]
	then
		echo "Skipping upload_hotfix as LIFERAY_RELEASE_UPLOAD is not set."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gsutil cp "${_BUILD_DIR}/${HOTFIX_FILE_NAME}" "gs://patcher-storage/hotfix/${DXP_VERSION}/"
}
