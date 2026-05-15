#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh

function check_usage {
	if [ -z "${JENKINS_API_TOKEN}" ] || [ -z "${LIFERAY_RELEASE_JENKINS_USER}" ]
	then
		echo "Usage: ${0}"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    JENKINS_API_TOKEN: API token of the Jenkins user that triggers the job build-release"
		echo "    LIFERAY_RELEASE_JENKINS_USER: Jenkins user that triggers the job build-release"

		exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
	fi
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_usage

	if is_latest_release_candidate_published
	then
		local skip_branch="release-$(get_product_group_version "$(get_latest_product_version "quarterly")")"
	fi

	local exit_code="${LIFERAY_COMMON_EXIT_CODE_OK}"

	for branch in $(get_premium_support_lts_release_branches)
	do
		if [ "${branch}" == "${skip_branch}" ]
		then
			lc_log INFO "Skipping ${branch} because it is covered by the automated build."

			continue
		fi

		if ! trigger_build_release "${branch}"
		then
			exit_code="${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done

	return "${exit_code}"
}

function trigger_build_release {
	local branch="${1}"

	local http_response=$(curl \
		"https://release-master.liferay.com/job/build-release/buildWithParameters" \
		--data-urlencode "LIFERAY_RELEASE_GIT_REF=${branch}" \
		--max-time 10 \
		--request "POST" \
		--retry 3 \
		--silent \
		--user "${LIFERAY_RELEASE_JENKINS_USER}:${JENKINS_API_TOKEN}" \
		--write-out "%{http_code}")

	if [ "${http_response}" == "201" ]
	then
		lc_log INFO "Triggered build-release for ${branch}."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	lc_log ERROR "Unable to trigger build-release for ${branch}. HTTP response: ${http_response}."

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

main "${@}"
