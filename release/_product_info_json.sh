#!/bin/bash

function generate_product_info_json {
	function write {
		echo -en "${1}" >> "${_PROMOTION_DIR}/.product_info.json.tmp"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log DEBUG "Updating ${_PROMOTION_DIR}/.product_info.json."

	sed \
		-e "s@\(${product_version}.*\),\"promoted\":\"true\",\(.*\)@\1,\"promoted\":\"false\",\2@" \
		-e "s/^\}/,/" \
		-i \
		"${_PROMOTION_DIR}/.product_info.json.tmp"

	local release_date=$(lc_get_property "${_PROMOTION_DIR}/release.properties" release.date)

	release_date=$(date -d "${release_date}" "+%m/%d/%Y")

	local bundle_url=$(lc_get_property "${_PROMOTION_DIR}/release.properties" bundle.url)

	bundle_url=$(obfuscate_url "${bundle_url}" "${release_date}")

	local md5_url="$(lc_get_property "${_PROMOTION_DIR}/release.properties" bundle.url).MD5"

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "${md5_url}" "${_PROMOTION_DIR}/bundle_md5.txt"

	local product_version=$(lc_get_property "${_PROMOTION_DIR}/release.properties" liferay.product.version)

	local product_key="${product_version,,}"

	product_key="${product_key// /-}"

	local target_platform_version=$(lc_get_property "${_PROMOTION_DIR}/release.properties" target.platform.version)

	target_platform_version="${target_platform_version/-/.}"

	writeln "\"${product_key}\": {"
	writeln "    \"appServerTomcatVersion\": \"$(lc_get_property "${_PROMOTION_DIR}/release.properties" app.server.tomcat.version)\","
	writeln "    \"bundleChecksumMD5\": \"$(<"${_PROMOTION_DIR}/bundle_md5.txt")\","
	writeln "    \"bundleChecksumMD5Url\": \"$(obfuscate_url "${md5_url}" "${release_date}")\","
	writeln "    \"bundleUrl\": \"${bundle_url}\","
	writeln "    \"liferayDockerImage\": \"$(lc_get_property "${_PROMOTION_DIR}/release.properties" liferay.docker.image)\","
	writeln "    \"liferayProductVersion\": \"${product_version}\","
	writeln "    \"promoted\": \"true\","
	writeln "    \"releaseDate\": \"${release_date}\","
	writeln "    \"targetPlatformVersion\": \"${target_platform_version}\""
	writeln "}"
	echo "}" >> "${_PROMOTION_DIR}/.product_info.json.tmp"

	jq "." "${_PROMOTION_DIR}/.product_info.json.tmp" > "${_PROMOTION_DIR}/.product_info.json"
}

function get_file_product_info_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/tools/workspace/.product_info.json" "${_PROMOTION_DIR}/.product_info.json.tmp"

	cp -f "${_PROMOTION_DIR}/.product_info.json.tmp" "${LIFERAY_COMMON_LOG_DIR}/.product_info.json-BACKUP.txt"

	sed \
		-z -i -r \
		-e 's@\r?\n        "@"@g' \
		-e 's@\r?\n    \}(,)?@\}\1@g' \
		-e 's@[ ]+"@"@g' \
		"${_PROMOTION_DIR}/.product_info.json.tmp"
}

function get_file_release_properties {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "https://releases.liferay.com/dxp/${LIFERAY_RELEASE_VERSION}/release.properties"
}

function obfuscate_url {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	local release_date="${2}"
	local url="${1}"

	java -jar "${_RELEASE_ROOT_DIR}/bin/com.liferay.workspace.bundle.url.codec.jar" "${url}" "${release_date}"
}

function upload_product_info_json {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_log INFO "Backing up to /www/releases.liferay.com/tools/workspace/.product_info.json.BACKUP."

	ssh -i lrdcom-vm-1 root@lrdcom-vm-1 cp -f "/www/releases.liferay.com/tools/workspace/.product_info.json" "/www/releases.liferay.com/tools/workspace/.product_info.json.BACKUP"

	lc_log DEBUG "Uploading ${_PROMOTION_DIR}/.product_info.json to /www/releases.liferay.com/tools/workspace/.product_info.json"

	scp -i lrdcom-vm-1 "${_PROMOTION_DIR}/.product_info.json" root@lrdcom-vm-1:/www/releases.liferay.com/tools/workspace/.product_info.json
}