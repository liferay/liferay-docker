#!/bin/bash

source ../_liferay_common.sh
source ./_jira.sh

function scan_release_candidate_docker_image {
	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		return
	fi

	LIFERAY_IMAGE_NAMES="liferay/release-candidates:${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"

	if [ "$(get_release_output)" == "nightly" ]
	then
		LIFERAY_IMAGE_NAMES="liferay/dxp:7.4.13.nightly"
	fi

	_scan_docker_images
}

function _notify_info_sec {
	if ! is_quarterly_release || [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Skipping InfoSec notification."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local issue_key="$( \
		add_jira_issue_with_description \
			"Sec R&D-Sec Engineering" \
			"Hi team, The ${1} scan had the following output: ${2}" \
			"${due_date}" \
			"Request" \
			"LRINFOSEC" \
			"${1} - Release Candidate | Prisma Cloud Scan Vulnerabilities")"

	if [[ "${issue_key}" != LRINFOSEC-* ]]
	then
		lc_log ERROR "Unable to create a Jira issue for ${1}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	else
		lc_log INFO "Jira issue ${issue_key} created successfully for ${1}."
	fi
}

function _scan_docker_images {
	if [ -z "${LIFERAY_IMAGE_NAMES}" ]
	then
		lc_log ERROR "\${LIFERAY_IMAGE_NAMES} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ -z "${LIFERAY_PRISMA_CLOUD_ACCESS_KEY}" ] ||
	   [ -z "${LIFERAY_PRISMA_CLOUD_SECRET}" ]
	then
		lc_log ERROR "Either \${LIFERAY_PRISMA_CLOUD_ACCESS_KEY} or \${LIFERAY_PRISMA_CLOUD_SECRET} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local api_url="https://api.eu.prismacloud.io"
	local data=$(
		cat <<- END
		{
			"password": "${LIFERAY_PRISMA_CLOUD_SECRET}",
			"username": "${LIFERAY_PRISMA_CLOUD_ACCESS_KEY}"
		}
		END
	)

	local auth_response=$(\
		curl \
			"${api_url}/login" \
			--data "${data}" \
			--header "Content-Type: application/json" \
			--request POST \
			--silent)

	if (! echo "${auth_response}" | grep --quiet "login_successful")
	then
		lc_log ERROR "Unable to authenticate with ${api_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local console_url="https://europe-west3.cloud.twistlock.com/eu-1614931"
	local token=$(echo "${auth_response}" | jq --raw-output '.token')

	curl \
		"${console_url}/api/v1/util/twistcli" \
		--header "x-redlock-auth: ${token}" \
		--output twistcli \
		--silent

	if [ ! -f "./twistcli" ]
	then
		lc_log ERROR "Unable to download twistcli."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	chmod +x ./twistcli

	local scan_result=0

	while read -r image_name
	do
		lc_log INFO "Scanning ${image_name}."

		local scan_output=$(\
			./twistcli images scan \
				--address "${console_url}" \
				--docker-address "$(\
					find \
						/run/user/$(id --user) \
						-name docker.sock 2> /dev/null)" \
				--password "${LIFERAY_PRISMA_CLOUD_SECRET}" \
				--user "${LIFERAY_PRISMA_CLOUD_ACCESS_KEY}" \
				"${image_name}")

		lc_log INFO "Scan output for ${image_name}:"

		lc_log INFO "${scan_output}"

		if [[ ${scan_output} == *"Compliance threshold check results: PASS"* ]] &&
		   [[ ${scan_output} == *"Vulnerability threshold check results: PASS"* ]]
		then
			lc_log INFO "The result of scan for ${image_name} is: PASS."
		elif [[ ${scan_output} == *"Compliance threshold check results: FAIL"* ]] ||
			 [[ ${scan_output} == *"Vulnerability threshold check results: FAIL"* ]]
		then
			lc_log INFO "The result of scan for ${image_name} is: FAIL."

			lc_log ERROR "The Docker image ${image_name} has security vulnerabilities."

			_notify_info_sec "${image_name}" "${scan_output}"

			scan_result="${LIFERAY_COMMON_EXIT_CODE_BAD}"
		else
			lc_log ERROR "Unable to determine the result of scan for ${image_name}."

			scan_result="${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done < <(echo "${LIFERAY_IMAGE_NAMES}" | tr ',' '\n')

	rm --force ./twistcli

	return "${scan_result}"
}