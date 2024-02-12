#!/bin/bash

source _liferay_common.sh
source _promotion.sh
source _publishing.sh
source _releases_json.sh

function check_usage {
	LIFERAY_RELEASE_PRODUCT_NAME=${LIFERAY_RELEASE_PRODUCT_NAME:-dxp}

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_RELEASE_ROOT_DIR="${PWD}"

	_PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

	_PRODUCT_VERSION_LIST_FILE="${_PROMOTION_DIR}/product_version_list.txt"

	rm -fr "${_PROMOTION_DIR}"

	mkdir -p "${_PROMOTION_DIR}"

	lc_cd "${_PROMOTION_DIR}"

	LIFERAY_COMMON_LOG_DIR="${_PROMOTION_DIR%/*}"
}

function main {
	check_usage

	lc_time_run generate_product_version_list_file dxp

	local product_version

	while IFS= read -r product_version
	do
		lc_time_run process_product_version dxp "${product_version}" || true
	done < "${_PRODUCT_VERSION_LIST_FILE}-dxp"

	lc_time_run generate_product_version_list_file portal

	while IFS= read -r product_version
	do
		lc_time_run process_product_version portal "${product_version}" || true
	done < "${_PRODUCT_VERSION_LIST_FILE}-portal"

	lc_time_run merge_json_snippets

	#lc_time_run upload_releases_json
}

main