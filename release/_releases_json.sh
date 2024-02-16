#!/bin/bash

function regenerate_releases_json {
	_process_product dxp

	_process_product portal

	_merge_json_snippets
}

function upload_releases_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log INFO "Backing up to /www/releases.liferay.com/releases.json.BACKUP."

	ssh root@lrdcom-vm-1 cp -f "/www/releases.liferay.com/releases.json" "/www/releases.liferay.com/releases.json.BACKUP"

	lc_log INFO "Uploading ${_PROMOTION_DIR}/releases.json to /www/releases.liferay.com/releases.json"

	scp "${_PROMOTION_DIR}/releases.json" "root@lrdcom-vm-1:/www/releases.liferay.com/releases.json"
}

function _merge_json_snippets {
	if (! jq -s add ./*.json > releases.json)
	then
		lc_log ERROR "Invalid JSON detected."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _process_product {
	local product_name="${1}"

	local release_directory_url="https://releases.liferay.com/${product_name}"

	local version_filter=$(tr '\n' '|' < "${_RELEASE_ROOT_DIR}/supported-${product_name}-versions.txt")

	lc_log INFO "Generating product version list from ${release_directory_url}."

	local directory_html=$(lc_curl "${release_directory_url}/")

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download the product version list."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	for product_version in  $(echo -en "${directory_html}" | \
		grep -E -o "(20[0-9]+\.q[0-9]\.[0-9]+|7\.[0-9]+\.[0-9]+[a-z0-9\.-]+)/" | \
		tr -d "/" | \
		uniq)
	do
		_process_product_version "${product_name}" "${product_version}"
	done
}

function _process_product_version {
	local product_name=${1}
	local product_version=${2}

	lc_log INFO "Processing ${product_name} ${product_version}."

	#
	# Must stay separate line, otherwise we would not get back the error code of lc_download
	#

	local release_properties_file

	release_properties_file=$(lc_download "https://releases.liferay.com/${product_name}/${product_version}/release.properties")

	local exit_code=${?}

	if [ "${exit_code}" == "${LIFERAY_COMMON_EXIT_CODE_MISSING_RESOURCE}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	elif [ "${exit_code}" == "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local grouping_version=$(echo "${product_version}" | sed -r "s@(^[0-9]+\.[0-9a-z]+)\..*@\1@")

	local release_date=$(lc_get_property "${release_properties_file}" release.date)

	(
		echo "["
		echo "{"
		echo "    \"group\":\"${grouping_version}\","
		echo "    \"product\": \"${product_name}\","
		echo "    \"productVersion\": \"$(lc_get_property "${release_properties_file}" liferay.product.version)\","
		echo "    \"promoted\": \"false\","
		echo "    \"releaseKey\":\"${product_name}-${product_version}\","
		echo "    \"url\": \"https://releases-cdn.liferay.com/${product_name}/${product_version}\""
		echo "}"
		echo "]"
	) >> "${release_date}-${product_name}-${product_version}.json"
}