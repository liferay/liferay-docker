#!/bin/bash

source ./_one_liferay.sh

function main {
	local license_dir=${1}
	local license_start_date=${2}
	local product_name=${3}

	mkdir --parents "${license_dir}/deploy"

	local license_file="${license_dir}/deploy/trial-${product_name}-license-${license_start_date}.xml"

	if [ "${product_name}" == "dxp" ]
	then
		_download_dxp_trial_license "${license_file}" "${license_start_date}"
	else
		_download_cms_trial_license "${license_file}" "${license_start_date}" "${product_name}"
	fi

	if [ ! -e "${license_file}" ]
	then
		echo "Trial ${product_name^^} license does not exist at ${license_file}."

		exit 1
	elif ! grep --quiet "docker@liferay.com" "${license_file}"
	then
		echo "Invalid trial ${product_name^^} license exists at ${license_file}."

		exit 1
	fi

	echo "Valid trial ${product_name^^} license exists at ${license_file}."
}

function _download_cms_trial_license {
	local license_file=${1}
	local license_start_date=${2}
	local product_name=${3}

	local license_api_oauth2_access_token=$(get_license_api_oauth2_access_token)

	if [ -z "${license_api_oauth2_access_token}" ]
	then
		echo "Unable to get an OAuth2 access token."

		exit 1
	fi

	if ! curl \
			--fail \
			--header "Authorization: Bearer ${license_api_oauth2_access_token}" \
			--output "${license_file}" \
			--retry 3 \
			--retry-delay 10 \
			--show-error \
			--silent \
			"https://liferayoneetcspringboot-exte5a2oneliferay-extprd.lfr.cloud/trial-license-keys/${product_name}?licenseLifetime=$((1000 * 60 * 60 * 24 * 90))&owner=docker%40liferay.com&startDate=${license_start_date}"
	then
		echo "Unable to get a trial ${product_name^^} license."

		exit 1
	fi
}

function _download_dxp_trial_license {
	local license_file=${1}
	local license_start_date=${2}

	if [ -z "${LIFERAY_DOCKER_LICENSE_API_HEADER}" ] ||
	   [ -z "${LIFERAY_DOCKER_LICENSE_API_URL}" ]
	then
		echo "Set the environment variables LIFERAY_DOCKER_LICENSE_API_HEADER and LIFERAY_DOCKER_LICENSE_API_URL to generate a trial DXP license."

		exit 1
	fi

	if ! curl \
			--fail \
			--header "${LIFERAY_DOCKER_LICENSE_API_HEADER}" \
			--retry 3 \
			--retry-delay 10 \
			--show-error \
			--silent \
			"${LIFERAY_DOCKER_LICENSE_API_URL}?licenseLifetime=$((1000 * 60 * 60 * 24 * 90))&owner=docker%40liferay.com&startDate=${license_start_date}" > "${license_file}.json"
	then
		echo "Unable to get a trial DXP license."

		exit 1
	fi

	sed --expression "s/\\\n//g" "${license_file}.json" | \
		sed --expression "s/\\\t//g" | \
		sed --expression "s/\"<?xml/<?xml/" | \
		sed --expression "s/license>\"/license>/" | \
		sed --expression "s/\\\\\"/\\\"/g" | \
		sed --expression "s/\\\\\\//\\//g" > "${license_file}"

	rm --force "${license_file}.json"
}

main "${@}"