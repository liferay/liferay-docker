#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ./_jira.sh

function check_usage {
	if [ -z "${LIFERAY_DOCKER_IMAGE_NAME}" ]
	then
		print_help
	fi
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_usage

	lc_time_run _scan_docker_image
}

function set_liferay_docker_image_name {
	export LIFERAY_DOCKER_IMAGE_NAME="liferay/release-candidates:${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"

	if [ "$(get_release_output)" == "nightly" ]
	then
		LIFERAY_DOCKER_IMAGE_NAME="liferay/dxp:7.4.13.nightly"
	fi

	lc_log INFO "Setting Liferay Docker image name to ${LIFERAY_DOCKER_IMAGE_NAME}"

	echo "LIFERAY_DOCKER_IMAGE_NAME=${LIFERAY_DOCKER_IMAGE_NAME}" > "/tmp/liferay_docker_image_name.properties"
}

function print_help {
	echo "Usage: LIFERAY_DOCKER_IMAGE_NAME=<<liferay_docker_image_name>> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_DOCKER_IMAGE_NAME: Liferay Docker image name to scan"
	echo "    LIFERAY_RELEASE_OUTPUT (optional): Set to \"nightly\" for nightly builds. The default is \"release-candidate\"."
	echo "    LIFERAY_RELEASE_UPLOAD (optional): Set this to \"true\" to notify info sec"
	echo ""
	echo "Example: LIFERAY_DOCKER_IMAGE_NAME=liferay/release-candidates:2025.q1.12-123456789 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function _is_info_sec_jira_issue_created {
	if [[ "${LIFERAY_INFO_SEC_JIRA_ISSUE_KEY}" == LRINFOSEC-* ]]
	then
		return 0
	fi

	return 1
}

function _notify_info_sec {
	if ! is_quarterly_release_docker_image "${LIFERAY_DOCKER_IMAGE_NAME}" || [ "${LIFERAY_RELEASE_UPLOAD}" != "true" ]
	then
		lc_log INFO "Skipping InfoSec notification."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	LIFERAY_INFO_SEC_JIRA_ISSUE_KEY="$( \
		add_jira_issue_with_description \
			"Sec R&D-Sec Engineering" \
			"Hi team, the Prisma Cloud Scan of image ${LIFERAY_DOCKER_IMAGE_NAME} had the following output: ${2}" \
			"$(get_due_date "3")" \
			"Request" \
			"LRINFOSEC" \
			"${LIFERAY_DOCKER_IMAGE_NAME} - Release Candidate | Prisma Cloud Scan Vulnerabilities")"

	if ! _is_info_sec_jira_issue_created
	then
		lc_log ERROR "Unable to create a Jira issue for ${LIFERAY_DOCKER_IMAGE_NAME}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	else
		lc_log INFO "Jira issue ${LIFERAY_INFO_SEC_JIRA_ISSUE_KEY} created successfully for ${LIFERAY_DOCKER_IMAGE_NAME}."
	fi
}

function _scan_docker_image {
	if [ -z "${LIFERAY_DOCKER_IMAGE_NAME}" ]
	then
		lc_log ERROR "\${LIFERAY_DOCKER_IMAGE_NAME} is undefined."

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

	local auth_response=$( \
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

	local scan_result="${LIFERAY_COMMON_EXIT_CODE_OK}"

	lc_log INFO "Scanning ${LIFERAY_DOCKER_IMAGE_NAME}."

	docker pull "${LIFERAY_DOCKER_IMAGE_NAME}"

	local scan_output=$( \
		./twistcli images scan \
			--address "${console_url}" \
			--docker-address "$( \
				find \
					/run/user/$(id --user) \
					-name docker.sock 2> /dev/null)" \
			--password "${LIFERAY_PRISMA_CLOUD_SECRET}" \
			--user "${LIFERAY_PRISMA_CLOUD_ACCESS_KEY}" \
			"${LIFERAY_DOCKER_IMAGE_NAME}")

	lc_log INFO "Scan output for ${LIFERAY_DOCKER_IMAGE_NAME}:"

	lc_log INFO "${scan_output}"

	if [[ ${scan_output} == *"Compliance threshold check results: PASS"* ]] &&
	   [[ ${scan_output} == *"Vulnerability threshold check results: PASS"* ]]
	then
		lc_log INFO "The result of scan for ${LIFERAY_DOCKER_IMAGE_NAME} is: PASS."
	else
		lc_log INFO "The result of scan for ${LIFERAY_DOCKER_IMAGE_NAME} is: FAIL."

		lc_log ERROR "The Liferay Docker image ${LIFERAY_DOCKER_IMAGE_NAME} has security vulnerabilities."

		scan_output=$(echo "${scan_output}" | perl -pe 's/\e\[[0-9;]*[mGJK]//g')

		_notify_info_sec "${scan_output}"

		local info_sec_jira_issue_message=""

		if _is_info_sec_jira_issue_created
		then
			info_sec_jira_issue_message="*Info Sec ticket:* https://liferay.atlassian.net/browse/${LIFERAY_INFO_SEC_JIRA_ISSUE_KEY}"
		fi

		local prisma_cloud_link=$( \
			echo "${scan_output}" | \
			grep \
				--extended-regexp \
				--only-matching \
				"https://\S+prismacloud.io\S+" | \
			head --lines=1)

		cat <<- END > scan_failure_slack_message.txt
		*Affected release:* \`$(echo "${LIFERAY_DOCKER_IMAGE_NAME}" | sed "s/.*://")\`

		*Prisma Cloud scan result:* ${prisma_cloud_link}

		${info_sec_jira_issue_message}
		END

		scan_result="${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	rm --force ./twistcli

	return "${scan_result}"
}

main "${@}"