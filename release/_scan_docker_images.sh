#!/bin/bash

source ../_liferay_common.sh

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
		else
			lc_log INFO "The result of scan for ${image_name} is: FAIL."

			lc_log ERROR "The Docker image ${image_name} has security vulnerabilities."

			scan_result="${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done < <(echo "${LIFERAY_IMAGE_NAMES}" | tr ',' '\n')

	rm --force ./twistcli

	return "${scan_result}"
}

function scan_release_candidate_docker_image {
	LIFERAY_IMAGE_NAMES="liferay/release-candidates:${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}"

	_scan_docker_images
}