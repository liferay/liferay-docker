#!/bin/bash

source ../_liferay_common.sh

function _deploy_product_zip_file {
	local product_zip_file_path=${1}

	if [ ! -f "${product_zip_file_path}" ]
	then
		lc_log ERROR "The product zip file ${product_zip_file_path} does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if (unzip -l "${product_zip_file_path}" | grep "client-extension" &>/dev/null)
	then
		cp "${product_zip_file_path}" "${_BUNDLES_DIR}/deploy"
	elif (unzip -l "${product_zip_file_path}" | grep "\.lpkg$" &>/dev/null)
	then
		unzip \
			-d "${_BUNDLES_DIR}/deploy" \
			-j \
			-o \
			-q \
			"${product_zip_file_path}" "*.lpkg" \
			-x "*/*" 2> /dev/null
	elif (unzip -l "${product_zip_file_path}" | grep "\.zip$" &>/dev/null)
	then
		unzip \
			-d "${_BUNDLES_DIR}/deploy" \
			-j \
			-o \
			-q \
			"${product_zip_file_path}" "*.zip" \
			-x "*/*" 2> /dev/null
	fi

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to deploy $(basename "${product_zip_file_path}") to ${_BUNDLES_DIR}/deploy."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _download_product {
	local product_download_url=${1}
	local product_file_name=${2}

	local http_status_code=$(\
		curl \
			"https://marketplace-uat.liferay.com/${product_download_url}" \
			--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
			--location \
			--output "${_BUILD_DIR}/marketplace/${product_file_name}" \
			--request GET \
			--silent \
			--write-out "%{http_code}")

	if [[ "${http_status_code}" -ge 400 ]]
	then
		lc_log ERROR "Unable to download product ${product_file_name}. HTTP status: ${http_status_code}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _download_product_by_external_reference_code {
	local product_external_reference_code=${1}
	local product_file_name=${2}

	local product_virtual_settings_file_entries=$(_get_product_virtual_settings_file_entries_by_external_reference_code "${product_external_reference_code}")

	if [ -z "${product_virtual_settings_file_entries}" ]
	then
		lc_log ERROR "Unable to get product virtual settings file entries."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local latest_product_virtual_settings_file_entry_json_index=$(_get_latest_product_virtual_settings_file_entry_json_index "${product_virtual_settings_file_entries}")

	if [ -z "${latest_product_virtual_settings_file_entry_json_index}" ]
	then
		lc_log ERROR "Unable to get JSON index for the latest product virtual settings file entry."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local product_download_url="$(echo "${product_virtual_settings_file_entries}" | jq --raw-output ".items[${latest_product_virtual_settings_file_entry_json_index}].src" | sed "s|^/||")"

	_download_product "${product_download_url}" "${product_file_name}.zip"

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _get_latest_product_virtual_settings_file_entry_json_index {
	local product_virtual_settings_file_entries_response=${1}

	local latest_product_virtual_settings_file_entry_json_index=$(\
		echo "${product_virtual_settings_file_entries_response}" | \
		jq ".items
			| to_entries
			| map(
				select(
					(.value.version // \"\")
					| test(\"Q[1-4]|7[.][0-4]\")
				)
			)
			| max_by([
				(.value.version | test(\"Q\")),
				(.value.version | split(\", \") | max)
			])
			| .key?")

	if [ "${latest_product_virtual_settings_file_entry_json_index}" == "null" ]
	then
		echo ""

		return
	fi

	echo "${latest_product_virtual_settings_file_entry_json_index}"
}

function _get_product_by_external_reference_code {
	local product_external_reference_code="${1}"

	local http_status_code_file=$(mktemp)

	local product_response=$(\
		curl \
			"https://marketplace-uat.liferay.com/o/headless-commerce-admin-catalog/v1.0/products/by-externalReferenceCode/${product_external_reference_code}?nestedFields=productVirtualSettings%2Cattachments" \
			--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
			--request GET \
			--silent \
			--write-out "%output{${http_status_code_file}}%{http_code}")

	local http_status_code=$(cat "${http_status_code_file}")

	if [[ "${http_status_code}" -ge 400 ]]
	then
		echo ""

		return
	fi

	echo "${product_response}"
}

function _get_product_virtual_settings_file_entries_by_external_reference_code {
	local product_external_reference_code=${1}

	local product_response=$(_get_product_by_external_reference_code "${product_external_reference_code}")

	if [ -z "${product_response}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local product_virtual_settings_id=$(echo "${product_response}" | jq --raw-output ".productVirtualSettings.id")

	local http_status_code_file=$(mktemp)

	local product_virtual_file_entries_response=$(\
		curl \
			"https://marketplace-uat.liferay.com/o/headless-commerce-admin-catalog/v1.0/product-virtual-settings/${product_virtual_settings_id}/product-virtual-settings-file-entries?pageSize=20" \
			--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
			--request GET \
			--silent \
			--write-out "%output{${http_status_code_file}}%{http_code}")

	local http_status_code=$(cat "${http_status_code_file}")

	if [[ "${http_status_code}" -ge 400 ]]
	then
		echo ""

		return
	fi

	echo "${product_virtual_file_entries_response}"
}

function _set_liferay_marketplace_oauth2_token {
	local http_status_code_file=$(mktemp)

	local liferay_marketplace_oauth2_token_response=$(\
		curl \
			"https://marketplace-uat.liferay.com/o/oauth2/token" \
			--data "client_id=${LIFERAY_MARKETPLACE_OAUTH2_CLIENT_ID}&client_secret=${LIFERAY_MARKETPLACE_OAUTH2_CLIENT_SECRET}&grant_type=client_credentials" \
			--request POST \
			--silent \
			--write-out "%output{${http_status_code_file}}%{http_code}")

	local http_status_code=$(cat "${http_status_code_file}")

	if [[ "${http_status_code}" -ge 400 ]]
	then
		lc_log ERROR "Unable to get Liferay Marketplace OAuth2 token. HTTP status: ${http_status_code}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	_LIFERAY_MARKETPLACE_OAUTH2_TOKEN=$(echo "${liferay_marketplace_oauth2_token_response}" | jq --raw-output ".access_token")
}

function _check_product_compatibility {
	local product_external_reference_code=${1}
	local product_name=${2}

	lc_log INFO "Checking the compatibility of product ${product_name} with ${_PRODUCT_VERSION} release."

	if [ ! -f "${_BUILD_DIR}/marketplace/${product_name}.zip" ]
	then
		lc_log ERROR "Unable to check compatibility for product ${product_name} because the product zip file ${product_name}.zip was not downloaded."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local modules_info=$(blade sh lb -s | grep "${product_name}")

	if [ -z "${modules_info}" ]
	then
		lc_log ERROR "Unable to check compatibility for product ${product_name}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if (echo "${modules_info}" | grep --extended-regexp --invert-match "Active|Resolved" &>/dev/null)
	then
		lc_log ERROR "One or more modules of ${product_name} are not compatible with release ${_PRODUCT_VERSION}:"

		while IFS= read -r module_info
		do
			local module_name=$(\
				echo "${module_info}" | \
				cut --delimiter "|" --fields=4 | \
				sed "s/ (.*)//" | \
				xargs)

			lc_log ERROR "Module ${module_name} is not compatible with release ${_PRODUCT_VERSION}."

			local module_id=$(echo "${module_info}" | cut --delimiter "|" --fields=1 | xargs)

			lc_log INFO "OSGI diagnostics: $(blade sh diag "${module_id}" | tail --lines=+3 | xargs)"

			if (grep --quiet "${module_name}" "${_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE}")
			then
				lc_log INFO "Deployment logs for ${module_name}:"

				cat "${_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE}" | grep "${module_name}"
			fi
		done <<< "${modules_info}"

		return
	fi

	lc_log INFO "Module ${product_name} is compatible with release ${_PRODUCT_VERSION}. Updating list of supported versions."

	_update_product_supported_versions "${product_external_reference_code}" "${product_name}"
}

function _update_product_supported_versions {
	local product_external_reference_code=${1}
	local product_name=${2}

	local product_virtual_settings_file_entries=$(_get_product_virtual_settings_file_entries_by_external_reference_code "${product_external_reference_code}")

	local latest_product_virtual_settings_file_entry_json_index=$(_get_latest_product_virtual_settings_file_entry_json_index "${product_virtual_settings_file_entries}")

	local latest_product_virtual_file_entry_version=$(echo "${product_virtual_settings_file_entries}" | jq --raw-output ".items[${latest_product_virtual_settings_file_entry_json_index}].version")

	local product_virtual_file_entry_target_version=$(get_product_group_version | tr "." " " | tr "[:lower:]" "[:upper:]")

	if [[ "${latest_product_virtual_file_entry_version}" != *"${product_virtual_file_entry_target_version}"* ]]
	then
		local latest_product_virtual_file_entry_id=$(echo "${product_virtual_settings_file_entries}" | jq --raw-output ".items[${latest_product_virtual_settings_file_entry_json_index}].id")

		local http_status_code=$(\
			curl \
				"https://marketplace-uat.liferay.com/o/headless-commerce-admin-catalog/v1.0/product-virtual-settings-file-entries/${latest_product_virtual_file_entry_id}" \
				--form "productVirtualSettingsFileEntry={\"version\": \"${latest_product_virtual_file_entry_version}, ${product_virtual_file_entry_target_version}\"};type=application/json" \
				--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
				--output /dev/null \
				--request PATCH \
				--silent \
				--write-out "%{http_code}")

		if [[ "${http_status_code}" -ge 400 ]]
		then
			lc_log ERROR "Unable to update the list of supported versions for product ${product_name}. HTTP status: ${http_status_code}."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		lc_log INFO "The supported versions list was successfully updated for product ${product_name} to include the ${product_virtual_file_entry_target_version} release."
	else
		lc_log INFO "The supported versions list for product ${product_name} already contains the ${product_virtual_file_entry_target_version} release."
	fi
}