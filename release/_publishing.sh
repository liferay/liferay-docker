#!/bin/bash

function init_gcs {
	if [ ! -n "${LIFERAY_RELEASE_GCS_TOKEN}" ]
	then
		lc_log INFO "The LIFERAY_RELEASE_GCS_TOKEN is not set."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gcloud auth activate-service-account --key-file "${LIFERAY_RELEASE_GCS_TOKEN}"
}

function upload_release {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "The environment variable LIFERAY_RELEASE_UPLOAD was not set to \"true\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_BUILD_DIR}"/release

	echo "# Uploaded files" > ../output.md

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/dxp/release-candidates/${_DXP_VERSION}-${_BUILD_TIMESTAMP}"

	for file in *
	do
		if [ -f "${file}" ]
		then
			# gsutil cp "${_BUILD_DIR}/release/${file}" "gs://patcher-storage/dxp/${_DXP_VERSION}/"

			echo "Copying ${file}."

			scp -i lrdcom-vm-1 "${file}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/release-candidates/${_DXP_VERSION}-${_BUILD_TIMESTAMP}"

			echo " - https://releases.liferay.com/dxp/release-candidates/${_DXP_VERSION}-${_BUILD_TIMESTAMP}/${file}" >> ../output.md
		fi
	done
}

function upload_hotfix {
	if [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "The environment variable LIFERAY_RELEASE_UPLOAD was not set to \"true\"."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 mkdir -p "/www/releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/"

	scp -i lrdcom-vm-1 "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" root@lrdcom-vm-1:"/www/releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/"

	echo "# Uploaded files" > ../output.md
	echo " - https://releases.liferay.com/dxp/hotfix/${_DXP_VERSION}/${_HOTFIX_FILE_NAME}" >> ../output.md

	# gsutil cp "${_BUILD_DIR}/${_HOTFIX_FILE_NAME}" "gs://patcher-storage/hotfix/${_DXP_VERSION}/"
}