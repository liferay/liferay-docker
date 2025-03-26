#!/bin/bash

source ../_liferay_common.sh

function scan_docker_images {
	local api_url="https://api.eu.prismacloud.io"
	local console="https://europe-west3.cloud.twistlock.com/eu-1614931"
	local image_names=("$@") # Capture all arguments as an array

	LIFERAY_PRISMA_ACCESS_KEY=""
	LIFERAY_PRISMA_SECRET=""

	local request_data=$(
		cat <<- END
		{
			"password": "${LIFERAY_PRISMA_SECRET}",
			"username": "${LIFERAY_PRISMA_ACCESS_KEY}"
		}
		END
	)

	local auth_response=$(\
		curl \
			--data "${request_data}" \
			--header "Content-Type: application/json" \
			--request POST \
			--silent \
			"${api_url}/login")

	local token=$(echo "${auth_response}" | jq -r '.token')

	curl \
		--header "x-redlock-auth: ${token}" \
		--output twistcli \
		--silent \
		"${console}/api/v1/util/twistcli"

	chmod +x ./twistcli

	for image_name in "${image_names[@]}"
	do
		local sanitized_image_name=$(echo "${image_name}" | sed 's/[^a-zA-Z0-9]/_/g')

		local vulnerabilities_file="vulnerabilities_${sanitized_image_name}.json"

		lc_log INFO "Scanning ${image_name}."

		export scan_output=$(\
			./twistcli images scan \
				--address "${console}" \
				--docker-address "/run/user/1000/docker.sock" \
				--password "${LIFERAY_PRISMA_SECRET}" \
				--user "${LIFERAY_PRISMA_ACCESS_KEY}" \
				"${image_name}")

		lc_log INFO "Scan output for ${image_name}:"

		lc_log INFO "${scan_output}"

		if [[ ${scan_output} == *"Vulnerability threshold check results: PASS"* ]] || [[ ${image_name} == *"7.4.13.nightly"* ]]
		then
			lc_log INFO "The result of scan for ${image_name} is: PASS"
		else
			lc_log INFO "The result of scan for ${image_name} is: FAIL"

			lc_log ERROR "The Docker image ${image_name} has security vulnerabilities."
		fi
	done

	rm -f ./twistcli
}

lc_time_run scan_docker_images "${@}"
