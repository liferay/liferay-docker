#!/bin/bash

source _liferay_common.sh

JIRA_TOKEN=""
JIRA_USER=""
SLACK_WEB_HOOK_URL=""

function main {
	lc_cd liferay-portal

	local git_pull_response=$(git pull origin master)

	if [[ "${git_pull_response}" == *"Already up to date"* ]]
	then
		lc_log INFO "The master branch hasn't been updated since the last run, so no changes in the blockers have occurred."

		exit "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local jira_api_response=$(\
		curl \
			"https://liferay.atlassian.net/rest/api/3/search?jql=project%20%3D%20%22PUBLIC%20-%20Liferay%20Product%20Delivery%22%20and%20labels%20%3D%20release-blocker%20and%20status%20%21%3D%20Closed&fields=issuekey" \
			--fail \
			--header 'Accept: application/json' \
			--max-time 10 \
			--request GET \
			--retry 3 \
			--silent \
			--user "${JIRA_USER}:${JIRA_TOKEN}")

	if [ $? -ne 0 ]
	then
		lc_log ERROR "Unable to retrive the list of blockers from Jira"

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local blocker_issues_keys=()

	while IFS= read -r key
	do
		blocker_issues_keys+=("${key}")
	done < <(echo "${jira_api_response}" | jq -r '.issues[].key')

	local blockers_not_merged=""

	for blocker_issue_key in "${blocker_issues_keys[@]}"
	do
		if [ -z "$(git log --grep="${blocker_issue_key}")" ]
		then
			blockers_not_merged+="<https://liferay.atlassian.net/browse/${blocker_issue_key}|${blocker_issue_key}> "
		fi
	done

	local slack_message="All blockers are merged"

	if [ -n "${blockers_not_merged}" ]
	then
		slack_message="These blockers still need to be merged: ${blockers_not_merged}"
	fi

	if (curl \
		"${SLACK_WEB_HOOK_URL}" \
		--data "{\"text\":\"${slack_message}\"}" \
		--fail \
		--header "Content-type: application/json" \
		--max-time 10 \
		--request POST \
		--retry 3 \
		--silent)
	then
		lc_log INFO "The Slack message has been sent successfully"
	else
		lc_log ERROR "The Slack message has not been sent successfully"

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

main