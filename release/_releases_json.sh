#!/bin/bash

function regenerate_releases_json {
	_process_product dxp
	_process_product portal

	_promote_product_versions dxp
	_promote_product_versions portal

	_merge_json_snippets
}

function upload_releases_json {
	lc_log INFO "Backing up to /www/releases.liferay.com/releases.json.BACKUP."

	ssh root@lrdcom-vm-1 cp -f "/www/releases.liferay.com/releases.json" "/www/releases.liferay.com/releases.json.BACKUP"

	lc_log INFO "Uploading ${_PROMOTION_DIR}/releases.json to /www/releases.liferay.com/releases.json."

	scp "${_PROMOTION_DIR}/releases.json" "root@lrdcom-vm-1:/www/releases.liferay.com/releases.json.upload"

	ssh root@lrdcom-vm-1 mv -f "/www/releases.liferay.com/releases.json.upload" "/www/releases.liferay.com/releases.json"
}

function _merge_json_snippets {
	if (! jq -s add ./*.json > releases.json)
	then
		lc_log ERROR "Detected invalid JSON."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _process_product {
	local product_name="${1}"

	local release_directory_url="https://releases.liferay.com/${product_name}"

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

	local release_properties_file

	#
	# Define release_properties_file in a separate line to capture the exit code.
	#

	release_properties_file=$(lc_download "https://releases.liferay.com/${product_name}/${product_version}/release.properties")

	local exit_code=${?}

	if [ "${exit_code}" == "${LIFERAY_COMMON_EXIT_CODE_MISSING_RESOURCE}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	elif [ "${exit_code}" == "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local release_date=$(lc_get_property "${release_properties_file}" release.date)

	if [ -z "${release_date}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	(
		echo "["
		echo "    {"
		echo "        \"product\": \"${product_name}\","
		echo "        \"productGroupVersion\": \"$(echo "${product_version}" | sed -r "s@(^[0-9]+\.[0-9a-z]+)\..*@\1@")\","
		echo "        \"productVersion\": \"$(lc_get_property "${release_properties_file}" liferay.product.version)\","
		echo "        \"promoted\": \"false\","
		echo "        \"releaseKey\":\"${product_name}-${product_version}\","
		echo "        \"url\": \"https://releases-cdn.liferay.com/${product_name}/${product_version}\""
		echo "    }"
		echo "]"
	) >> "${release_date}-${product_name}-${product_version}.json"
}


function _promote_product_versions {
	local product_name=${1}

	while IFS= read -r group_version
	do
		# shellcheck disable=SC2010
		last_version=$(ls | grep "${product_name}-${group_version}" | head -n 1 2>/dev/null)

		if [ -n "${last_version}" ]
		then
			lc_log INFO "Promoting ${last_version}."

			sed -i 's/"promoted": "false"/"promoted": "true"/' "${last_version}"
		else
			lc_log INFO "No product version found to promote for ${product_name}-${group_version}."
		fi
	done < "${_RELEASE_ROOT_DIR}/supported-${product_name}-versions.txt"
}