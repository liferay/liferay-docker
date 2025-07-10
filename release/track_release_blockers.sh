#!/bin/bash

source ../_liferay_common.sh

function check_usage {
	if [ -z "$LIFERAY_TRACK_RELEASE_BLOCKERS_JIRA_TOKEN" ] ||
	   [ -z "$LIFERAY_TRACK_RELEASE_BLOCKERS_JIRA_USER" ] ||
       [ -z "$LIFERAY_TRACK_RELEASE_BLOCKERS_SLACK_URL" ]
	then
		echo "Usage: ${0}"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_TRACK_RELEASE_BLOCKERS_JIRA_TOKEN"
		echo "    LIFERAY_TRACK_RELEASE_BLOCKERS_JIRA_USER"
		echo "    LIFERAY_TRACK_RELEASE_BLOCKERS_SLACK_URL"
		echo ""
		echo "Example: LIFERAY_TRACK_RELEASE_BLOCKERS_JIRA_TOKEN=123456789 LIFERAY_TRACK_RELEASE_BLOCKERS_JIRA_USER=joe.bloggs@liferay.com ${0}"

		exit 1
	fi
}

function main {
	check_usage

	lc_cd /home/me/liferay-portal

	local git_pull_response=$(git pull origin master)

	if [[ "${git_pull_response}" == *"Already up to date"* ]]
	then
		lc_log INFO "The master branch is already up to date."

		exit "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local jira_api_response=$(\
		curl \
			"https://liferay.atlassian.net/rest/api/3/search?fields=issuekey&jql=labels%20%3D%20release-blocker%20and%20project%20%3D%20%22PUBLIC%20-%20Liferay%20Product%20Delivery%22%20and%20status%20%21%3D%20Closed" \
			--fail \
			--header "Accept: application/json" \
			--max-time 10 \
			--request GET \
			--retry 3 \
			--silent \
			--user "${JIRA_USER}:${JIRA_TOKEN}")

	if [ $? -ne 0 ]
	then
		lc_log ERROR "Unable to get a list of blockers from Jira."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local unmerged_issue_keys=""

	local blocker_issues_keys=()

	while IFS= read -r key
	do
		blocker_issues_keys+=("${key}")
	done < <(echo "${jira_api_response}" | jq --raw-output ".issues[].key")

	for blocker_issue_key in "${blocker_issues_keys[@]}"
	do
		if [ -z "$(git log --grep="${blocker_issue_key}")" ]
		then
			unmerged_issue_keys+="<https://liferay.atlassian.net/browse/${blocker_issue_key}|${blocker_issue_key}> "
		fi
	done

	local slack_message="All blockers are merged."

	if [ -n "${unmerged_issue_keys}" ]
	then
		slack_message="These blockers are not merged: ${unmerged_issue_keys}."
	fi

	if (curl \
			"${LIFERAY_TRACK_RELEASE_BLOCKERS_SLACK_URL}" \
			--data-raw '{
				"text": "'"${slack_message}"'"
			}' \
			--fail \
			--header "Content-type: application/json" \
			--max-time 10 \
			--request POST \
			--retry 3 \
			--silent)
	then
		lc_log INFO "Sent Slack message."
	else
		lc_log ERROR "Unable to send Slack message."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

main "${@}"