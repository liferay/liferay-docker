#!/bin/bash

source ../_liferay_common.sh

function check_usage {
	if [ -z "${LIFERAY_IMAGE_NAMES}" ] ||
	   [ -z "${LIFERAY_PRISMA_CLOUD_ACCESS_KEY}" ] ||
	   [ -z "${LIFERAY_PRISMA_CLOUD_SECRET}" ]
	then
		print_help
	fi

	local image_name

	while read -r image_name
	do
		if [ -z "$(docker images --quiet "${image_name}" 2> /dev/null)" ]
		then
			lc_log ERROR "Unable to find ${image_name} locally."

			exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done <<< "$(echo "${LIFERAY_IMAGE_NAMES}" | tr ',' '\n')"

	lc_cd "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")"

	_RELEASE_ROOT_DIR="${PWD}"

	LIFERAY_COMMON_LOG_DIR="${_RELEASE_ROOT_DIR}/logs"

	mkdir --parents "${LIFERAY_COMMON_LOG_DIR}"
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_usage

	lc_time_run scan_docker_images
}

function print_help {
	echo "Usage: LIFERAY_IMAGE_NAMES=<image name> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_IMAGE_NAMES: Comma separated list of DXP or Portal Docker images"
	echo "    LIFERAY_PRISMA_CLOUD_ACCESS_KEY: Prisma Cloud access key"
	echo "    LIFERAY_PRISMA_CLOUD_SECRET: Prisma Cloud secret"
	echo ""
	echo "Example: LIFERAY_IMAGE_NAMES=liferay/dxp:2025.q1.5-lts,liferay/dxp:2024.q2.2 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function scan_docker_images {
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

	scan_docker_images
}

main