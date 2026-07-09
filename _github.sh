#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/_liferay_common.sh"

function download_file_from_github {
	local file_name=${1}
	local file_path=${2}
	local ref=${3}
	local repository_name=${4}

	local http_response=$( \
		curl \
			--header "Accept: application/vnd.github.v3.raw" \
			--header "Authorization: token ${LIFERAY_RELEASE_GITHUB_PAT}" \
			--include \
			--max-time 10 \
			--output "${file_name}" \
			--request GET \
			--retry 3 \
			--write-out "%{http_code}" \
			"https://api.github.com/repos/liferay/${repository_name}/contents/${file_path}?ref=${ref}")

	if [ "${http_response}" != "200" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function invoke_github_api_delete {
	_invoke_github_api "${1}" "${2}" "${3}" "DELETE"

	echo "${?}"
}

function invoke_github_api_post {
	_invoke_github_api "${1}" "${2}" "${3}" "POST"

	echo "${?}"
}

function _invoke_github_api {
	local curl_response=$( \
		curl \
			--data "${3}" \
			--fail \
			--header "Accept: application/vnd.github+json" \
			--header "Authorization: Bearer ${LIFERAY_RELEASE_GITHUB_PAT}" \
			--header "X-GitHub-Api-Version: 2022-11-28" \
			--include \
			--max-time 10 \
			--request "${4}" \
			--retry 3 \
			--silent \
			"https://api.github.com/repos/${1}/${2}")

	local http_code=$(echo "${curl_response}" | awk '/^HTTP/{print $2}')

	if ! [[ "${http_code}" =~ ^2 ]]
	then
		lc_log ERROR "Unable to ${4} https://api.github.com/repos/${1}/${2}. HTTP response code was ${http_code}." > /dev/stderr

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_OK}"
}