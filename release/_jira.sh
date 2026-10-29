#!/bin/bash

source ../_liferay_common.sh

function add_jira_issue {
	local data=$(
		cat <<- END
		{
			"fields": {
				"assignee": {
					"id": "${1}"
				},
				"components": [
					{
						"name": "${2}"
					}
				],
				"issuetype": {
					"name": "${3}"
				},
				"project": {
					"key": "${4}"
				},
				"summary": "${5}",
				"${6}": "${7}"
			}
		}
		END
	)

	_invoke_jira_api "https://liferay.atlassian.net/rest/api/3/issue/" "${data}"
}

function add_jira_issue_comment {
	local data=$(
		cat <<- END
		{
			"body": {
				"content": [
					{
						"content": [
							{
								"text": "${1}",
								"type": "text"
							}
						],
						"type": "paragraph"
					}
				],
				"type": "doc",
				"version": 1
			}
		}
		END
	)

	_invoke_jira_api "https://liferay.atlassian.net/rest/api/3/issue/${2}/comment" "${data}"
}

function add_jira_issue_with_description {
	local data=$( \
		jq --null-input \
			"{
				fields: {
					components: [
						{
							name: \"${1}\"
						}
					],
					description: \"${2}\",
					duedate: \"${3}\",
					issuetype: {
						name: \"${4}\"
					},
					project: {
						key: \"${5}\"
					},
					summary: \"${6}\"
				}
			}")

	_invoke_jira_api "https://liferay.atlassian.net/rest/api/2/issue/" "${data}"
}

function close_jira_issue {
	local data=$(
		cat <<- END
		{
			"fields": {
				"resolution": {
					"name": "Completed"
				}
			},
			"transition": {
				"id": "71"
			}
		}
		END
	)

	if [ "$(_invoke_jira_api "https://liferay.atlassian.net/rest/api/3/issue/${1}/transitions" "${data}")" == "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		lc_log ERROR "Unable to close the Jira issue ${1}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _invoke_jira_api {
	local http_response

	http_response=$( \
		curl \
			--data "${2}" \
			--fail \
			--header "Accept: application/json" \
			--header "Content-Type: application/json" \
			--max-time 10 \
			--request "POST" \
			--retry 3 \
			--silent \
			--user "${LIFERAY_RELEASE_JIRA_USER}:${LIFERAY_RELEASE_JIRA_TOKEN}" \
			"${1}")

	if [[ "${?}" -eq 0 ]] && [ "$(echo "${http_response}" | jq --exit-status '.id?')" != "null" ]
	then
		echo "${http_response}" | jq --raw-output '.key'

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	echo "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}