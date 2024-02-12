#!/bin/bash

function add_version_snippet {
	local minor_version="${1}"
	local product_version="${2}"
	local promoted_status="${3}"
	local release_properties_file="${4}"

	lc_log INFO "Adding json snippet to ${_RELEASES_TMP_JSON_FILE}."

	(
		echo "{"
		echo "    \"${product_version}\": {"
		echo "        \"liferayProductVersion\": \"$(lc_get_property "${release_properties_file}" liferay.product.version)\","
		echo "        \"group\":\"${minor_version}\","
		echo "        \"product\": \"${LIFERAY_RELEASE_PRODUCT_NAME}\","
		echo "        \"promoted\": \"${promoted_status}\""
		echo "    }"
		echo "}"
	) >> "${_RELEASES_TMP_JSON_FILE}"
}

function generate_product_version_list_file {
	local release_directory_url="https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}"
	local version_filter=$(tr '\n' '|' < "${_RELEASE_ROOT_DIR}/supported-${LIFERAY_RELEASE_PRODUCT_NAME}-versions.txt")


	lc_log INFO "Generating product version list from ${release_directory_url}/ to ${_PRODUCT_VERSION_LIST_FILE}"

	set -o pipefail

	lc_curl "${release_directory_url}/" - | \
		grep -E -o "(20[0-9]+\.q[0-9]\.[0-9]+|[0-9]\.[0-9]+\.[0-9]+[a-z0-9\.-]+)/" | \
		grep -E "^(${version_filter})\." | \
		tr -d "/" | \
		uniq - "${_PRODUCT_VERSION_LIST_FILE}"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download the product version list."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_file_release_properties {
	local product_version="${1}"

	local release_properties_url="https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${product_version}/release.properties"

	local http_code=$(curl "${release_properties_url}" --fail --head --max-time 10 -o /dev/null --retry 3 --retry-delay 5 --silent --write-out "%{http_code}")

	lc_log DEBUG "HTTP return code: ${http_code}."

	if [ "${http_code}" == "200" ]
	then
		lc_log DEBUG "The file '${release_properties_url}' is reachable for downloading."
	elif [ "${http_code}" == "404" ]
	then
		lc_log INFO "No file exists on '${release_properties_url}' for downloading."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log ERROR "Unable to check the availability of ${release_properties_url}."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if (! lc_download "${release_properties_url}")
	then
		lc_log ERROR "Unable to download ${release_properties_url}."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function merge_json_snippets {
	if (! jq -s add "${_RELEASES_TMP_JSON_FILE}" > releases.json)
	then
		lc_log ERROR "Invalid JSON detected."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function process_product_version {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	local product_version="${1}"

	local release_properties_url="https://releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${product_version}/release.properties"
	local release_properties_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${release_properties_url##*://}"

	if [ -f "${release_properties_file}" ]
	then
		lc_log INFO "Using ${release_properties_file} from the cache."
	else
		lc_log INFO "Downloading ${release_properties_url} to the cache."

		get_file_release_properties "${product_version}" || return "${?}"
	fi

	local minor_version=$(echo "${product_version}" | sed -r "s@(^[0-9]+\.[0-9a-z]+)\..*@\1@")
	local last_version=$(grep "^${minor_version}" "${_PRODUCT_VERSION_LIST_FILE}" | tail -1)

	lc_log DEBUG "Defining promoted status of the version ${product_version}"

	if [ "${product_version}" == "${last_version}" ]
	then
		promoted_status="true"
	else
		promoted_status="false"
	fi

	add_version_snippet "${minor_version}" "${product_version}" "${promoted_status}" "${release_properties_file}"
}

function upload_releases_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log INFO "Backing up to /www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/releases.json.BACKUP."

	ssh root@lrdcom-vm-1 cp -f "/www/releases.liferay.com/releases.json" "/www/releases.liferay.com/releases.json.BACKUP"

	lc_log INFO "Uploading ${_PROMOTION_DIR}/releases.json to /www/releases.liferay.com/releases.json"

	scp "${_PROMOTION_DIR}/releases.json" "root@lrdcom-vm-1:/www/releases.liferay.com/releases.json"
}
