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
	_tag_recommended_product_versions

	_merge_json_snippets

	_upload_releases_json
}

function _add_database_schema_versions {
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
                | to_entries
                | sort_by(.key)
                | from_entries
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
				| to_entries
				| sort_by(.key)
				| from_entries
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

	local database_schema_version=$(\
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

function _get_liferay_upgrade_folder_version {
	local product_version=${1}

	if is_quarterly_release "${product_version}"
	then
		echo "v7_4_x"
	else
		echo "v$(get_product_group_version "${product_version}" | tr '.' '_')_x"
	fi
}

function _merge_json_snippets {
	if (! jq --slurp add $(ls ./*.json | sort --reverse) > releases.json)
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

	local releases_json=""

	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		releases_json="${_PROMOTION_DIR}/releases.json"
	else
		releases_json="${_PROMOTION_DIR}/0000-00-00-releases.json"

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
		)" "${releases_json}" > temp_file.json && mv temp_file.json "${releases_json}"

	if (is_7_3_release || is_7_4_release)
	then
		jq "map(
				if .product == \"${LIFERAY_RELEASE_PRODUCT_NAME}\" and .productGroupVersion == \"${product_group_version}\"
				then
					del(.tags)
				else
					.
				end
			)" "${releases_json}" > temp_file.json && mv temp_file.json "${releases_json}"
	elif is_quarterly_release && [ "$(get_latest_product_version "lts")" == "${_PRODUCT_VERSION}" ]
	then
		jq "map(
				if .productGroupVersion | test(\"q\")
				then
					del(.tags)
				else
					.
				end
			)" "${releases_json}" > temp_file.json && mv temp_file.json "${releases_json}"
	fi

	_process_product_version "${LIFERAY_RELEASE_PRODUCT_NAME}" "${_PRODUCT_VERSION}"
}

function _process_products {
	for product_name in "dxp" "portal"
	do
		local product_version_list_html

		product_version_list_html=$(_download_product_version_list_html "${product_name}")

		if [ "${?}" -ne 0 ]
		then
			lc_log ERROR "Unable to download the product version list."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		for product_version in $(echo -en "${product_version_list_html}" | \
			grep \
				--extended-regexp \
				--only-matching \
				"(20[0-9]+\.q[0-9]\.[0-9]+(-lts)?|7\.[0-9]+\.[0-9]+[a-z0-9\.-]+)/" | \
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

	tee "${release_date}-${product_name}-${product_version}.json" <<- END
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

				sed --in-place 's/"promoted": "false"/"promoted": "true"/' "${last_version}"
			else
				lc_log INFO "No product version found to promote for ${product_name}-${group_version}."
			fi
		done < "${_RELEASE_ROOT_DIR}/supported-${product_name}-versions.txt"
	done
}

function _tag_recommended_product_versions {
	for product_version in "ga" "lts"
	do
		local latest_product_version=$(get_latest_product_version "${product_version}")

		lc_log INFO "Latest product version for ${product_version} release is ${latest_product_version}."

		local latest_product_version_json_file=$(find "${_PROMOTION_DIR}" -type f -name "*${latest_product_version}.json")

		if [ -f "${latest_product_version_json_file}" ]
		then
			lc_log INFO "Tagging ${latest_product_version_json_file} as recommended."

			jq "map(
					(. + {tags: [\"recommended\"]})
					| to_entries
					| sort_by(.key)
					| from_entries
				)" "${latest_product_version_json_file}" > "${latest_product_version_json_file}.tmp" && mv "${latest_product_version_json_file}.tmp" "${latest_product_version_json_file}"
		else
			lc_log INFO "Unable to get latest product version JSON file for ${product_version}."
		fi
	done
}

function _upload_releases_json {
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