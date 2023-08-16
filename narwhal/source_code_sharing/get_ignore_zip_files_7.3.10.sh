#!/bin/bash

set -eo pipefail

IFS=$'\n\t'

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

ZIP_CACHE_DIR="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/storage.bud.liferay.com/public/files.liferay.com/private/ee/fix-packs/7.3.10/hotfix"

function get_list_zip_files {

	local zip_file

	for zip_file in "${ZIP_CACHE_DIR}"/*.zip
	do
		if (unzip -p "${zip_file}" fixpack_documentation.json | jq -r '.patch.requirements' | grep -E -q "^(base-|dxp-|sp[1-9])")
		then
			zip_file="${zip_file##*/}"

			echo "${zip_file}"
		fi
	done
}

get_list_zip_files
