#!/bin/bash

source ../_github.sh
source ../_release_common.sh

function generate_releases_json {
	if [ "${1}" = "regenerate" ]
	then
		_process_products
	else
		_process_new_product

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi

	_add_database_schema_versions
	_add_major_versions
	_promote_product_versions
	_tag_jakarta_product_versions
	_tag_recommended_product_versions
	_tag_supported_product_versions

	_sort_all_releases_json_attributes

	_merge_json_snippets

	_upload_releases_json
}

function _add_database_schema_versions {
	lc_log INFO "Adding database schema versions."

	local product_version_json_file

	for product_version_json_file in $(find "${_PROMOTION_DIR}" -maxdepth 1 -type f | grep --extended-regexp "[0-9]{4}-[0-9]{2}-[0-9]{2}-(dxp|portal).*\.json")
	do
		local product_version=$(jq --raw-output ".[].url" "${product_version_json_file}" | xargs basename)

		if [ "$(get_product_group_version "${product_version}")" == "7.0" ]
		then
			continue
		fi

		local repository="liferay-portal-ee"

		if [ "$(jq --raw-output ".[].product" "${product_version_json_file}")" == "portal" ]
		then
			repository="liferay-portal"
		fi

		local database_schema_version=$(_get_database_schema_version "${product_version}" "${repository}")

		if [ -z "${database_schema_version}" ]
		then
			lc_log ERROR "Unable to get database schema version for ${product_version} release."

			continue
		fi

		jq "map(
				. + {databaseSchemaVersion: \"${database_schema_version}\"}
			)" "${product_version_json_file}" > "${product_version_json_file}.tmp" && mv "${product_version_json_file}.tmp" "${product_version_json_file}"
	done
}

function _add_major_versions {
	local quarterly_release_json_file

	for quarterly_release_json_file in "${_PROMOTION_DIR}"/*q*.json
	do
		if [ ! -e "${quarterly_release_json_file}" ]
		then
			lc_log INFO "Skipping major version addition because the new version is not a quarterly release."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		local product_major_version=$(jq --raw-output ".[].productVersion" "${quarterly_release_json_file}" | sed "s/\.[0-9]\+//");

		jq "map(
				. + {productMajorVersion: \"${product_major_version}\"}
			)" "${quarterly_release_json_file}" > "${quarterly_release_json_file}.tmp" && mv "${quarterly_release_json_file}.tmp" "${quarterly_release_json_file}"
	done
}

function _get_database_schema_version {
	local product_version=${1}
	local repository=${2}

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		rm --force "${_PROMOTION_DIR}/PortalUpgradeProcessRegistryImpl.java"

		download_file_from_github \
			"PortalUpgradeProcessRegistryImpl.java" \
			"portal-impl/src/com/liferay/portal/upgrade/$(_get_liferay_upgrade_folder_version "${product_version}")/PortalUpgradeProcessRegistryImpl.java" \
			"$(get_product_version_without_lts_suffix "${product_version}")" \
			"${repository}" &> /dev/null

		if [ "${?}" -ne 0 ]
		then
			rm --force "${_PROMOTION_DIR}/PortalUpgradeProcessRegistryImpl.java"

			echo ""

			return
		fi
	fi

	local database_schema_version=$( \
		grep \
			--only-matching \
			--perl-regexp "(?<=new Version\()[^)]+(?=\))" \
			"${_PROMOTION_DIR}/PortalUpgradeProcessRegistryImpl.java" 2> /dev/null | \
		tail --lines=1 | \
		cut --delimiter=',' --fields=1,2,3 | \
		tr ',' '.' | \
		tr --delete '[:space:]')

	if [ -z "${database_schema_version}" ] ||
	   [[ ! "${database_schema_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
	then
		rm --force "${_PROMOTION_DIR}/PortalUpgradeProcessRegistryImpl.java"

		echo ""

		return
	fi

	echo "${database_schema_version}"
}

function _get_general_availability_date {
	local product_name=${1}
	local product_version=${2}

	local release_properties_file

	release_properties_file=$(lc_download "https://releases.liferay.com/${product_name}/${product_version}/release.properties")

	if [ "${?}" -ne 0 ]
	then
		echo ""

		return
	fi

	local date_key="release.date"

	set_actual_product_version "${product_version}"

	if (is_7_4_u_release "${product_version}" && is_later_product_version_than "7.4.13-u145") ||
	   (is_quarterly_release "${product_version}" && ! is_early_product_version_than "2026.q1.0-lts")
	then
		date_key="general.availability.date"
	fi

	local general_availability_date=$(lc_get_property "${release_properties_file}" "${date_key}")

	if [ -z "${general_availability_date}" ]
	then
		echo ""

		return
	fi

	echo "${general_availability_date}"
}

function _get_liferay_upgrade_folder_version {
	local product_version=${1}

	if is_quarterly_release "${product_version}"
	then
		echo "v7_4_x"
	else
		echo "v$(get_product_group_version "${product_version}" | tr '.' '_')_x"
	fi
}

function _get_supported_product_group_versions {
	local supported_product_group_versions=$( \
		ls "${_PROMOTION_DIR}" | \
		grep \
			--extended-regexp \
			--only-matching \
			"(7\.[2-4]|20[0-9][0-9]\.q[1-4])" | \
		sort --unique)

	local latest_product_version=$( \
		echo "${supported_product_group_versions}" | \
		grep ".q" | \
		tail --lines=1)

	local quarter=$(get_release_quarter "${latest_product_version}")
	local year=$(get_release_year "${latest_product_version}")

	if [ "${quarter}" -lt 4 ]
	then
		quarter=$((quarter + 1))
	else
		quarter=1
		year=$((year + 1))
	fi

	supported_product_group_versions+=$'\n'"${year}.q${quarter}"

	echo "${supported_product_group_versions}" | sort
}

function _is_supported_product_version {
	local product_version=${1}

	local general_availability_date=""
	local years=""

	if is_quarterly_release "${product_version}"
	then
		if [[ $(get_release_year "${product_version}") -eq 2023 ]]
		then
			return 1
		fi

		local product_group_version=$(get_product_group_version "${product_version}")

		if [ "${product_group_version}" == "2024.q1" ]
		then
			general_availability_date=$(_get_general_availability_date "dxp" "2024.q1.1")
			years=3
		elif is_lts_release "${product_version}"
		then
			general_availability_date=$(_get_general_availability_date "dxp" "${product_group_version}.0-lts")
			years=3
		else
			general_availability_date=$(_get_general_availability_date "dxp" "${product_group_version}.0")
			years=1
		fi
	elif [ "${product_version}" == "7.4.13-u92" ]
	then
		general_availability_date=$(_get_general_availability_date "dxp" "7.4.13-u92")
		years=4
	fi

	if [[ ! "${general_availability_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
	then
		return 1
	fi

	local end_of_premium_support_date=$(date --date "${general_availability_date} +${years} year -1 day" +%Y-%m-%d)
	local today=$(date +%Y-%m-%d)

	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		today="${LIFERAY_RELEASE_TEST_DATE}"
	fi

	if [[ "${today}" > "${end_of_premium_support_date}" ]]
	then
		return 1
	fi

	return 0
}

function _merge_json_snippets {
	if (! jq --slurp add $(ls "${_PROMOTION_DIR}"/*.json | sort --reverse) > "${_PROMOTION_DIR}/releases.json")
	then
		lc_log ERROR "Detected invalid JSON."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _process_new_product {
	if is_7_4_release
	then
		if [[ "$(get_release_version_trivial)" -gt 112 ]]
		then
			lc_log INFO "${_PRODUCT_VERSION} should not be added to releases.json."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi

	local releases_json="${_PROMOTION_DIR}/0000-00-00-releases.json"

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		if [ ! -f "${releases_json}" ]
		then
			lc_log INFO "Downloading https://releases.liferay.com/releases.json to ${releases_json}."

			LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download https://releases.liferay.com/releases.json "${releases_json}"
		fi
	fi

	if (grep "${_PRODUCT_VERSION}" "${releases_json}")
	then
		lc_log INFO "The version ${_PRODUCT_VERSION} is already in releases.json."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local product_group_version="$(get_product_group_version)"

	jq "map(
			if .product == \"${LIFERAY_RELEASE_PRODUCT_NAME}\" and .productGroupVersion == \"${product_group_version}\"
			then
				.promoted = \"false\"
			else
				.
			end
		)" "${releases_json}" > "${releases_json}.tmp" && mv "${releases_json}.tmp" "${releases_json}"

	jq "map(
			del(.tags)
		)" "${releases_json}" > "${releases_json}.tmp" && mv "${releases_json}.tmp" "${releases_json}"

	_process_product_version "${LIFERAY_RELEASE_PRODUCT_NAME}" "${_PRODUCT_VERSION}"
}

function _process_products {
	for product_name in "dxp" "portal"
	do
		local product_version_list_html

		product_version_list_html=$(download_product_version_list_html "${product_name}")

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to download the product version list."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		for product_version in $(echo -en "${product_version_list_html}" | \
			grep \
				--extended-regexp \
				--only-matching \
				"(20[0-9]+\.q[0-9]\.[0-9]+(-lts)?|7\.[0-9]+\.[0-9]+[a-z0-9\.-]+)" | \
			tr --delete '/' | \
			uniq)
		do
			if [[ $(echo "${product_version}" | grep "7.4") ]] && [[ $(echo "${product_version}" | cut --delimiter='u' --fields=2) -gt 112 ]]
			then
				continue
			fi

			_process_product_version "${product_name}" "${product_version}"
		done
	done
}

function _process_product_version {
	local product_name=${1}
	local product_version=${2}

	lc_log INFO "Processing ${product_name} ${product_version}."

	local release_properties_file

	release_properties_file=$(lc_download "https://releases.liferay.com/${product_name}/${product_version}/release.properties")

	local exit_code=${?}

	if [ "${exit_code}" == "${LIFERAY_COMMON_EXIT_CODE_MISSING_RESOURCE}" ]
	then
		lc_log INFO "Skipping ${product_name} ${product_version} because the release.properties file is missing."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	elif [ "${exit_code}" == "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to process ${product_name} ${product_version}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local general_availability_date=$(_get_general_availability_date "${product_name}" "${product_version}")

	if [[ ! "${general_availability_date}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]
	then
		lc_log INFO "Skipping ${product_name} ${product_version} because the general availability date is missing."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	tee "${_PROMOTION_DIR}/${general_availability_date}-${product_name}-${product_version}.json" <<- END
	[
	    {
	        "product": "${product_name}",
	        "productGroupVersion": "$(echo "${product_version}" | sed --regexp-extended "s@(^[0-9]+\.[0-9a-z]+)\..*@\1@")",
	        "productVersion": "$(lc_get_property "${release_properties_file}" liferay.product.version)",
	        "promoted": "false",
	        "releaseKey": "$(echo "${product_name}-${product_version}" | sed "s/\([0-9]\+\)\.\([0-9]\+\)\.[0-9]\+\(-\|[^0-9]\)/\1.\2\3/g" | sed --expression "s/portal-7\.4\.[0-9]*-ga/portal-7.4-ga/")",
	        "targetPlatformVersion": "$(lc_get_property "${release_properties_file}" target.platform.version)",
	        "url": "https://releases-cdn.liferay.com/${product_name}/${product_version}"
	    }
	]
	END
}

function _promote_product_versions {
	for product_name in "dxp" "portal"
	do
		while read -r group_version || [ -n "${group_version}" ]
		do
			# shellcheck disable=SC2010
			last_version=$(ls "${_PROMOTION_DIR}" | grep "${product_name}-${group_version}" | tail --lines=1 2>/dev/null)

			if [ -n "${last_version}" ]
			then
				lc_log INFO "Promoting ${last_version}."

				sed --in-place 's/"promoted": "false"/"promoted": "true"/' "${_PROMOTION_DIR}/${last_version}"
			else
				lc_log INFO "No product version found to promote for ${product_name}-${group_version}."
			fi
		done < <(_get_supported_product_group_versions)
	done
}

function _sort_all_releases_json_attributes {
	lc_log INFO "Sorting all releases.json attributes."

	local json_file

	while read -r json_file
	do
		jq "map(
				to_entries
				| sort_by(.key)
				| from_entries
			)" "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
	done < <(find "${_PROMOTION_DIR}" -maxdepth 1 -name "*.json" -type f)
}

function _tag_jakarta_product_versions {
	lc_log INFO "Tagging product versions with Jakarta support."

	local json_file

	while read -r json_file
	do
		jq "map(
				if (.productGroupVersion? | (contains(\"q\") and . >= \"2025.q3\"))
				then
					.tags = ((.tags // []) + [\"jakarta\"] | unique)
				else
					.
				end
			)" "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
	done < <(find "${_PROMOTION_DIR}" -maxdepth 1 -name "*.json" -type f)
}

function _tag_recommended_product_versions {
	local latest_ga_product_version=$(get_latest_product_version "ga")
	local latest_lts_product_version=$(get_latest_product_version "lts")

	lc_log INFO "Tagging ${latest_ga_product_version} and ${latest_lts_product_version} as recommended."

	local json_file

	while read -r json_file
	do
		jq "map(
				if (.url? | (endswith(\"${latest_ga_product_version}\") or endswith(\"${latest_lts_product_version}\")))
				then
					.tags = ((.tags // []) + [\"recommended\"] | unique)
				else
					.
				end
			)" "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
	done < <(find "${_PROMOTION_DIR}" -maxdepth 1 -name "*.json" -type f)
}

function _tag_supported_product_versions {
	lc_log INFO "Tagging product versions with active premium support."

	local json_file

	while read -r json_file
	do
		while read -r product_version_url
		do
			local product_version=$(basename "${product_version_url}")

			if ([ "${product_version}" == "7.4.13-u92" ] || is_quarterly_release "${product_version}") &&
			   _is_supported_product_version "${product_version}"
			then
				jq "map(
						if (.url? | (endswith(\"${product_version}\")))
						then
							.tags = ((.tags // []) + [\"supported\"] | unique)
						else
							.
						end
					)" "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
			fi
		done < <(jq --raw-output ".[].url" "${json_file}")
	done < <(find "${_PROMOTION_DIR}" -maxdepth 1 -name "*.json" -type f)
}

function _upload_releases_json {
	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		return
	fi

	ssh root@lrdcom-vm-1 "exit" &> /dev/null

	if [ "${?}" -eq 0 ]
	then
		lc_log INFO "Backing up to /www/releases.liferay.com/releases.json.BACKUP."

		ssh root@lrdcom-vm-1 cp --force "/www/releases.liferay.com/releases.json" "/www/releases.liferay.com/releases.json.BACKUP"

		lc_log INFO "Uploading ${_PROMOTION_DIR}/releases.json to /www/releases.liferay.com/releases.json."

		scp "${_PROMOTION_DIR}/releases.json" "root@lrdcom-vm-1:/www/releases.liferay.com/releases.json.upload"

		ssh root@lrdcom-vm-1 mv --force "/www/releases.liferay.com/releases.json.upload" "/www/releases.liferay.com/releases.json"
	fi

	lc_log INFO "Backing up to gs://liferay-releases/releases.json.BACKUP."

	gsutil cp "gs://liferay-releases/releases.json" "gs://liferay-releases/releases.json.BACKUP"

	lc_log INFO "Uploading ${_PROMOTION_DIR}/releases.json to gs://liferay-releases/releases.json."

	gsutil cp "${_PROMOTION_DIR}/releases.json" "gs://liferay-releases/releases.json.upload"

	gsutil mv "gs://liferay-releases/releases.json.upload" "gs://liferay-releases/releases.json"
}