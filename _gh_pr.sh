#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/_liferay_common.sh"

function close_pull_request {
	local query=${1}
	local repository=${2}

	lc_log INFO "Checking for an open pull request to close in ${repository}."

	local existing_pull_request=$( \
		gh pr list \
			--jq ".[0]" \
			--json "number" \
			--repo "${repository}" \
			--search "${query}" \
			--state "open")

	if [ -z "${existing_pull_request}" ]
	then
		lc_log INFO "No open pull request found in ${repository}."

		return
	fi

	local pull_request_number=$( \
		echo "${existing_pull_request}" | jq --raw-output ".number")

	lc_log INFO "Closing existing pull request #${pull_request_number}."

	gh pr close "${pull_request_number}" --repo "${repository}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to close existing pull request #${pull_request_number} in ${repository}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function create_pull_request {
	local base_branch=${1}
	local branch_name=${2}
	local repository=${3}
	local title=${4}

	lc_log INFO "Creating pull request \"${title}\" in ${repository}."

	gh pr create \
		--base "${base_branch}" \
		--body "This pull request was automatically created by the Release team." \
		--head "liferay-release:${branch_name}" \
		--repo "${repository}" \
		--title "${title}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to create pull request in ${repository}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_pull_request_url {
	local branch_name=${1}
	local repository=${2}

	gh pr view \
		--jq ".url" \
		--json "url" \
		--repo "${repository}" \
		"liferay-release:${branch_name}"
}
