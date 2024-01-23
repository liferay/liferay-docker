#!/bin/bash

function generate_product_info_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	function write {
		echo -en "${1}" >> "${_PROMOTION_DIR}/.product_info_tmp.json"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	sed -i \
		-e "s@\(${product_version}.*\),\"promoted\":\"true\",\(.*\)@\1,\"promoted\":\"false\",\2@" \
		-e "s/^\}/,/" \
		"${_PROMOTION_DIR}/.product_info_tmp.json"

	local release_date_raw=$(lc_get_property "${_PROMOTION_DIR}/release.properties" release.date)
	local release_date_formatted=$(date -d "${release_date_raw}" "+%m/%d/%Y")

	local bundle_url_raw=$(lc_get_property "${_PROMOTION_DIR}/release.properties" bundle.url)
	local bundle_url_formatted=$(obfuscate_url "${bundle_url_raw}" "${release_date_formatted}")

	local docker_image=$(lc_get_property "${_PROMOTION_DIR}/release.properties" liferay.docker.image)

	local md5_url_raw="$(lc_get_property "${_PROMOTION_DIR}/release.properties" bundle.url).MD5"
	local md5_url_formatted=$(obfuscate_url "${md5_url_raw}" "${release_date_formatted}")

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "${md5_url_raw}" "${_PROMOTION_DIR}/bundle_md5.txt"

	local md5_hash=$(<"${_PROMOTION_DIR}/bundle_md5.txt")

	local product_version=$(lc_get_property "${_PROMOTION_DIR}/release.properties" liferay.product.version)

	local product_key="${product_version,,}"
	product_key="${product_key// /-}"

	local target_platform_version_raw=$(lc_get_property "${_PROMOTION_DIR}/release.properties" target.platform.version)
	local target_platform_version_formatted="${target_platform_version_raw/-/.}"

	local tomcat_version=$(lc_get_property "${_PROMOTION_DIR}/release.properties" app.server.tomcat.version)

	lc_log DEBUG "Adding snippet to ${_PROMOTION_DIR}/.product_info.json."

	writeln "\"${product_key}\": {"
	writeln "    \"appServerTomcatVersion\": \"${tomcat_version}\","
	writeln "    \"bundleChecksumMD5\": \"${md5_hash}\","
	writeln "    \"bundleChecksumMD5Url\": \"${md5_url_formatted}\","
	writeln "    \"bundleUrl\": \"${bundle_url_formatted}\","
	writeln "    \"liferayDockerImage\": \"${docker_image}\","
	writeln "    \"liferayProductVersion\": \"${product_version}\","
	writeln "    \"promoted\": \"true\","
	writeln "    \"releaseDate\": \"${release_date_formatted}\","
	writeln "    \"targetPlatformVersion\": \"${target_platform_version_formatted}\""
	writeln "}"
	echo "}" >> "${_PROMOTION_DIR}/.product_info_tmp.json"

	jq '.' "${_PROMOTION_DIR}/.product_info_tmp.json" > "${_PROMOTION_DIR}/.product_info.json"
}

function get_file_product_info_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/tools/workspace/.product_info.json" "${_PROMOTION_DIR}/.product_info_tmp.json"

	cp -f "${_PROMOTION_DIR}/.product_info_tmp.json" "${LIFERAY_COMMON_LOG_DIR}/.product_info.json-BACKUP.txt"

	sed -i -r -z \
		-e 's@\r?\n        "@"@g' \
		-e 's@\r?\n    \}(,)?@\}\1@g' \
		-e 's@[ ]+"@"@g' \
		"${_PROMOTION_DIR}/.product_info_tmp.json"
}

function get_file_release_properties {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}/release.properties"
}

function obfuscate_url {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	url="${1}"
	release_date="${2}"

	"${_RELEASE_ROOT_DIR}/url-coder-1.0.0.jar" "${url}" "${release_date}"
}

function upload_product_info_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log INFO "Making a backup copy to /www/releases.liferay.com/tools/workspace/.product_info.json.BACKUP on the server"

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 cp -f "/www/releases.liferay.com/tools/workspace/.product_info.json" "/www/releases.liferay.com/tools/workspace/.product_info.json.BACKUP"

	lc_log DEBUG "Uploading ${_PROMOTION_DIR}/.product_info.json to /www/releases.liferay.com/tools/workspace/.product_info.json"

	scp -i lrdcom-vm-1 "${_PROMOTION_DIR}/.product_info.json" root@lrdcom-vm-1:/www/releases.liferay.com/tools/workspace/.product_info.json
}