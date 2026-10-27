#!/bin/bash

source ../_liferay_common.sh

function check_usage {
	if [ -z "${LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME}" ] ||
	   [ -z "${LIFERAY_RELEASE_UPLOAD_SOURCE_DIR}" ]
	then
		print_help
	fi

	if ! _is_valid_upload_destination_dir_name "${LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME}"
	then
		lc_log ERROR "\${LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME} must only contain letters, numbers, \".\", \"_\", and \"-\", and must start with a letter or number."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if ! _is_valid_upload_source_dir "${LIFERAY_RELEASE_UPLOAD_SOURCE_DIR}"
	then
		lc_log ERROR "\${LIFERAY_RELEASE_UPLOAD_SOURCE_DIR} must be a relative path whose directory names only contain letters, numbers, \".\", \"_\", and \"-\", and start with a letter or number."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_check_utils gcloud || exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	_SOURCE_DIR="gs://liferay-releases-candidates/liferay-ide/${LIFERAY_RELEASE_UPLOAD_SOURCE_DIR}"

	if ! gcloud storage ls "${_SOURCE_DIR}" &> /dev/null
	then
		lc_log ERROR "${_SOURCE_DIR} does not exist."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	_DESTINATION_DIR="gs://liferay-releases/tools/ide/${LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME}"
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_usage

	lc_time_run _delete_destination_dir "${_DESTINATION_DIR}"

	lc_time_run _upload_files "${_SOURCE_DIR}" "${_DESTINATION_DIR}"
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME=<upload_destination_dir_name> LIFERAY_RELEASE_UPLOAD_SOURCE_DIR=<upload_source_dir> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME: Name of the directory under gs://liferay-releases/tools/ide to upload to. Its existing contents are deleted before uploading."
	echo "    LIFERAY_RELEASE_UPLOAD_SOURCE_DIR: Directory relative to gs://liferay-releases-candidates/liferay-ide to upload from"
	echo ""
	echo "Example: LIFERAY_RELEASE_UPLOAD_DESTINATION_DIR_NAME=4.0.1 LIFERAY_RELEASE_UPLOAD_SOURCE_DIR=4.x/202608072258 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function _delete_destination_dir {
	if ! gcloud storage ls "${1}" &> /dev/null
	then
		lc_log INFO "${1} does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if ! gcloud storage rm --recursive "${1}"
	then
		lc_log ERROR "Unable to delete ${1}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _is_valid_upload_destination_dir_name {
	if [[ "${1}" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ ]]
	then
		return 0
	fi

	return 1
}

function _is_valid_upload_source_dir {
	if [[ "${1}" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*(/[0-9A-Za-z][0-9A-Za-z._-]*)*$ ]]
	then
		return 0
	fi

	return 1
}

function _upload_files {
	if ! gcloud storage cp --recursive "${1}/*" "${2}/"
	then
		lc_log ERROR "Unable to upload ${1} to ${2}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

main