#!/bin/bash

source ../_liferay_common.sh

function check_usage {
	if [ -z "${LIFERAY_IMAGE_NAMES}" ] ||
	   [ -z "${LIFERAY_PRISMA_ACCESS_KEY}" ] ||
	   [ -z "${LIFERAY_PRISMA_SECRET}" ]
	then
		print_help
	fi

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_RELEASE_ROOT_DIR="${PWD}"

	LIFERAY_COMMON_LOG_DIR="${_RELEASE_ROOT_DIR}/logs"

	mkdir -p "${LIFERAY_COMMON_LOG_DIR}"
}

function main {
	check_usage

	lc_time_run scan_docker_images
}

function print_help {
	echo "Usage: LIFERAY_IMAGE_NAMES=<image name> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_IMAGE_NAMES: Comma-separated list of DXP or Portal Docker images"
	echo "    LIFERAY_PRISMA_ACCESS_KEY: An access key configured in the job environment variables"
	echo "    LIFERAY_PRISMA_SECRET: A secret configured in the job environment variables"
	echo ""
	echo "Example: LIFERAY_IMAGE_NAMES=liferay/dxp:2025.q1.5-lts,liferay/dxp:2024.q2.2 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function scan_docker_images {
	local api_url="https://api.eu.prismacloud.io"
	local data=$(
		cat <<- END
		{
			"password": "${LIFERAY_PRISMA_SECRET}",
			"username": "${LIFERAY_PRISMA_ACCESS_KEY}"
		}
		END
	)

	local auth_response=$(\
		curl \
			--data "${data}" \
			--header "Content-Type: application/json" \
			--request POST \
			--silent \
			"${api_url}/login")

	if (! echo "${auth_response}" | grep -q "login_successful")
	then
		lc_log ERROR "Unable to authenticate in ${api_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local console_url="https://europe-west3.cloud.twistlock.com/eu-1614931"
	local token=$(echo "${auth_response}" | jq -r '.token')

	curl \
		--header "x-redlock-auth: ${token}" \
		--output twistcli \
		--silent \
		"${console_url}/api/v1/util/twistcli"

	if ! [ -f "./twistcli" ]
	then
		lc_log ERROR "Unable to download twistcli."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	chmod +x ./twistcli

	echo "${LIFERAY_IMAGE_NAMES}" | tr ',' '\n' | while read -r image_name
	do
		lc_log INFO "Scanning ${image_name}."

		local scan_output=$(\
			./twistcli images scan \
				--address "${console_url}" \
				--docker-address "$(\
					find \
						/run/user/$(id -u) \
						-name docker.sock 2> /dev/null)" \
				--password "${LIFERAY_PRISMA_SECRET}" \
				--user "${LIFERAY_PRISMA_ACCESS_KEY}" \
				"${image_name}")

		lc_log INFO "Scan output for ${image_name}:"

		lc_log INFO "${scan_output}"

		if [[ ${scan_output} == *"Compliance threshold check results: PASS"* ]] &&
		   [[ ${scan_output} == *"Vulnerability threshold check results: PASS"* ]]
		then
			lc_log INFO "The result of scan for ${image_name} is: PASS"
		else
			lc_log INFO "The result of scan for ${image_name} is: FAIL"

			lc_log ERROR "The Docker image ${image_name} has security vulnerabilities."
		fi
	done

	rm -f ./twistcli
}

main