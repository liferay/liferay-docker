#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ./_product.sh

function check_liferay_marketplace_products_compatibility {
	if ! is_first_quarterly_release
	then
		lc_log INFO "The compatibility of Liferay Marketplace products should not be checked on the ${_PRODUCT_VERSION} release."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		_set_liferay_marketplace_oauth2_token

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		mkdir --parents "${_BUILD_DIR}/marketplace"

		declare -A LIFERAY_MARKETPLACE_PRODUCTS=(
			["adyen"]="f05ab2d6-1d54-c72d-988a-91fcd5669ef3"
			["drools"]="15099181"
			["liferaycommerceminium4globalcss"]="bee3adc0-891c-5828-c4f6-3d244135c972"
			["liferaypaypalbatch"]="a1946869-212f-0793-d703-b623d0f149a6"
			["liferayupscommerceshippingengine"]="f1cb4b5e-fbdd-7f70-df5d-9f1a736784b2"
			["opensearch"]="ea19fdc8-b908-690d-9f90-15edcdd23a87"
			["punchout"]="175496027"
			["solr"]="30536632"
			["stripe"]="6a02a832-083b-f08c-888a-0a59d7c09119"
		)
	fi

	for liferay_marketplace_product_name in $(printf "%s\n" "${!LIFERAY_MARKETPLACE_PRODUCTS[@]}" | sort --ignore-case)
	do
		if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
		then
			lc_log INFO "Downloading Liferay Marketplace product ${liferay_marketplace_product_name}."

			_download_product_by_external_reference_code "${LIFERAY_MARKETPLACE_PRODUCTS[${liferay_marketplace_product_name}]}" "${liferay_marketplace_product_name}"

			if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
			then
				return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
			fi
		fi

		lc_log INFO "Deploying Liferay Marketplace product zip file ${liferay_marketplace_product_name}.zip to ${_BUNDLES_DIR}/deploy.\n"

		_deploy_liferay_marketplace_product_zip_file "${_BUILD_DIR}/marketplace/${liferay_marketplace_product_name}.zip"

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done

	rm --force "${_BUILD_DIR}/warm-up-tomcat"

	_LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE="${_BUILD_DIR}/log_$(date +%s)_liferay_marketplace_products_deployment.txt"

	warm_up_tomcat "print-startup-logs" > "${_LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE}"

	echo "include-and-override=portal-developer.properties" > "${_BUNDLES_DIR}/portal-ext.properties"

	start_tomcat "print-startup-logs" >> "${_LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE}"

	for liferay_marketplace_product_name in $(printf "%s\n" "${!LIFERAY_MARKETPLACE_PRODUCTS[@]}" | sort --ignore-case)
	do
		_check_liferay_marketplace_product_compatibility "${LIFERAY_MARKETPLACE_PRODUCTS[${liferay_marketplace_product_name}]}" "${liferay_marketplace_product_name}"

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			stop_tomcat &> /dev/null

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done

	stop_tomcat &> /dev/null
}

function _check_liferay_marketplace_product_compatibility {
	local product_external_reference_code=${1}
	local product_name=${2}

	lc_log INFO "Checking the compatibility of Liferay Marketplace product ${product_name} with ${_PRODUCT_VERSION} release."

	if [ ! -f "${_BUILD_DIR}/marketplace/${product_name}.zip" ]
	then
		lc_log ERROR "Unable to check the compatibility of Liferay Marketplace product ${product_name} because the product zip file ${product_name}.zip was not downloaded.\n"

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local modules_info=$(blade sh lb -s | grep "${product_name}")

	if [ -z "${modules_info}" ]
	then
		lc_log ERROR "Unable to check the compatibility of Liferay Marketplace product ${product_name}.\n"

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if (echo "${modules_info}" | grep --extended-regexp --invert-match "Active|Resolved" &> /dev/null)
	then
		lc_log ERROR "One or more modules of Liferay Marketplace product ${product_name} are not compatible with release ${_PRODUCT_VERSION}:"

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

			if (grep --quiet "${module_name}" "${_LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE}")
			then
				lc_log INFO "Deployment logs for ${module_name}:"

				cat "${_LIFERAY_MARKETPLACE_PRODUCTS_DEPLOYMENT_LOG_FILE}" | grep "${module_name}"
			fi
		done <<< "${modules_info}"

		echo ""

		return
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		lc_log INFO "Module ${product_name} is compatible with release ${_PRODUCT_VERSION}. Updating list of supported versions."

		_update_product_supported_versions "${product_external_reference_code}" "${product_name}"
	fi
}

function _deploy_liferay_marketplace_product_zip_file {
	local liferay_marketplace_product_zip_file_path=${1}

	if [ ! -f "${liferay_marketplace_product_zip_file_path}" ]
	then
		lc_log ERROR "The Liferay Marketplace product zip file ${liferay_marketplace_product_zip_file_path} does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if (unzip -l "${liferay_marketplace_product_zip_file_path}" | grep "client-extension" &> /dev/null)
	then
		cp "${liferay_marketplace_product_zip_file_path}" "${_BUNDLES_DIR}/deploy"
	elif (unzip -l "${liferay_marketplace_product_zip_file_path}" | grep "\.lpkg$" &> /dev/null)
	then
		unzip \
			-d "${_BUNDLES_DIR}/deploy" \
			-j \
			-o \
			-q \
			"${liferay_marketplace_product_zip_file_path}" "*.lpkg" \
			-x "*/*" 2> /dev/null
	elif (unzip -l "${liferay_marketplace_product_zip_file_path}" | grep "\.zip$" &> /dev/null)
	then
		unzip \
			-d "${_BUNDLES_DIR}/deploy" \
			-j \
			-o \
			-q \
			"${liferay_marketplace_product_zip_file_path}" "*.zip" \
			-x "*/*" 2> /dev/null
	fi

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to deploy $(basename "${liferay_marketplace_product_zip_file_path}") to ${_BUNDLES_DIR}/deploy."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _download_product {
	local product_download_url=${1}
	local product_file_name=${2}

	local http_code=$(\
		curl \
			"https://marketplace.liferay.com/${product_download_url}" \
			--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
			--location \
			--output "${_BUILD_DIR}/marketplace/${product_file_name}" \
			--request GET \
			--silent \
			--write-out "%{http_code}")

	if [[ "${http_code}" -ge 400 ]]
	then
		lc_log ERROR "Unable to download product ${product_file_name}. HTTP code: ${http_code}."

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
	local product_virtual_settings_file_entries=${1}

	local latest_product_virtual_settings_file_entry_json_index=$(\
		echo "${product_virtual_settings_file_entries}" | \
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
	local product_external_reference_code=${1}

	local http_code_file=$(mktemp)

	local product=$(\
		curl \
			"https://marketplace.liferay.com/o/headless-commerce-admin-catalog/v1.0/products/by-externalReferenceCode/${product_external_reference_code}?nestedFields=productVirtualSettings%2Cattachments" \
			--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
			--request GET \
			--silent \
			--write-out "%output{${http_code_file}}%{http_code}")

	local http_code=$(cat "${http_code_file}")

	if [[ "${http_code}" -ge 400 ]]
	then
		echo ""

		rm --force "${http_code_file}"

		return
	fi

	rm --force "${http_code_file}"

	echo "${product}"
}

function _get_product_virtual_settings_file_entries_by_external_reference_code {
	local product_external_reference_code=${1}

	local product=$(_get_product_by_external_reference_code "${product_external_reference_code}")

	if [ -z "${product}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local product_virtual_settings_id=$(echo "${product}" | jq --raw-output ".productVirtualSettings.id")

	local http_code_file=$(mktemp)

	local product_virtual_settings_file_entries=$(\
		curl \
			"https://marketplace.liferay.com/o/headless-commerce-admin-catalog/v1.0/product-virtual-settings/${product_virtual_settings_id}/product-virtual-settings-file-entries?pageSize=20" \
			--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
			--request GET \
			--silent \
			--write-out "%output{${http_code_file}}%{http_code}")

	local http_code=$(cat "${http_code_file}")

	if [[ "${http_code}" -ge 400 ]]
	then
		echo ""

		rm --force "${http_code_file}"

		return
	fi

	rm --force "${http_code_file}"

	echo "${product_virtual_settings_file_entries}"
}

function _set_liferay_marketplace_oauth2_token {
	local http_code_file=$(mktemp)

	local liferay_marketplace_oauth2_token_response=$(\
		curl \
			"https://marketplace.liferay.com/o/oauth2/token" \
			--data "client_id=${LIFERAY_MARKETPLACE_OAUTH2_CLIENT_ID}&client_secret=${LIFERAY_MARKETPLACE_OAUTH2_CLIENT_SECRET}&grant_type=client_credentials" \
			--request POST \
			--silent \
			--write-out "%output{${http_code_file}}%{http_code}")

	local http_code=$(cat "${http_code_file}")

	if [[ "${http_code}" -ge 400 ]]
	then
		lc_log ERROR "Unable to get Liferay Marketplace OAuth2 token. HTTP code: ${http_code}."

		rm --force "${http_code_file}"

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	rm --force "${http_code_file}"

	_LIFERAY_MARKETPLACE_OAUTH2_TOKEN=$(echo "${liferay_marketplace_oauth2_token_response}" | jq --raw-output ".access_token")
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

		local http_code=$(\
			curl \
				"https://marketplace.liferay.com/o/headless-commerce-admin-catalog/v1.0/product-virtual-settings-file-entries/${latest_product_virtual_file_entry_id}" \
				--form "productVirtualSettingsFileEntry={\"version\": \"${latest_product_virtual_file_entry_version}, ${product_virtual_file_entry_target_version}\"};type=application/json" \
				--header "Authorization: Bearer ${_LIFERAY_MARKETPLACE_OAUTH2_TOKEN}" \
				--output /dev/null \
				--request PATCH \
				--silent \
				--write-out "%{http_code}")

		if [[ "${http_code}" -ge 400 ]]
		then
			lc_log ERROR "Unable to update the list of supported versions for product ${product_name}. HTTP code: ${http_code}.\n"

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		lc_log INFO "The supported versions list was successfully updated for product ${product_name} to include the ${product_virtual_file_entry_target_version} release.\n"
	else
		lc_log INFO "The supported versions list for product ${product_name} already contains the ${product_virtual_file_entry_target_version} release.\n"
	fi
}