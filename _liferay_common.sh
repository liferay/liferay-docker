#!/bin/bash

##
# Only edit this file in the root of the liferay-docker repository. If you need
# to make changes to it, please edit there first, commit and then copy it to
# your tool.
##

function lc_cd {
	cd "${3}" || exit 3
}

function lc_download {
	url=${1}
	file=${2}

	if [ -z "${url}" ] || [ -z "${file}" ]
	then
		lc_log ERROR "Invalid parameters for lc_download, it requires url and file"

		return 1
	fi

	if [ -e "${file}" ]
	then
		lc_log DEBUG "Skipping the download of ${url} as it already exists"

		return
	fi

	cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${url##*://}"

	if [ -e "${cache_file}" ]
	then
		lc_log DEBUG "Copying file from cache: ${cache_file}"

		cp "${cache_file}" "${file}"

		return
	fi

	mkdir -p $(dirname "${cache_file}")

	lc_log DEBUG "Downloading ${url}"

	if (! curl "${url}" --fail --output "${cache_file}_temp" --silent)
	then
		lc_log ERROR "Downloading ${url} was unsuccessful, exiting"

		return 4
	else
		mv "${cache_file}_temp" "${cache_file}"

		cp "${cache_file}" "${file}"
	fi
}

function lc_log {
	local level=${1}
	local message=${2}

	if [ "${level}" != "DEBUG" ] || [ "${LIFERAY_COMMON_LOG_LEVEL}" == "DEBUG" ]
	then
		echo "$(date) [${level}] ${message}"
	fi
}

function _lc_init {
	if [ -z "${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}" ]
	then
		LIFERAY_COMMON_DOWNLOAD_CACHE_DIR=${HOME}/.liferay-download-cache
	fi
}

_lc_init