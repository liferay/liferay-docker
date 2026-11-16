#!/bin/bash

source ./_one_liferay.sh

function main {
	local license_api_oauth2_access_token=$(get_license_api_oauth2_access_token)

	if [ -z "${license_api_oauth2_access_token}" ]
	then
		echo "Unable to get an OAuth2 access token."

		exit 1
	fi

	local license_dir=${1}
	local license_start_date=${2}
	local product_name=${3}

	mkdir --parents "${license_dir}/deploy"

	local license_file_name="trial-${product_name}-license-${license_start_date}.xml"

	if ! curl \
			--fail \
			--header "Authorization: Bearer ${license_api_oauth2_access_token}" \
			--output "${license_dir}/deploy/${license_file_name}" \
			--retry 3 \
			--retry-delay 10 \
			--show-error \
			--silent \
			"https://liferayoneetcspringboot-exte5a2oneliferay-extprd.lfr.cloud/trial-license-keys/${product_name}?licenseLifetime=$((1000 * 60 * 60 * 24 * 90))&owner=docker%40liferay.com&startDate=${license_start_date}"
	then
		echo "Unable to get a trial ${product_name^^} license."

		exit 1
	fi

	if [ ! -e "${license_dir}/deploy/${license_file_name}" ]
	then
		echo "Trial ${product_name^^} license does not exist at ${license_dir}/deploy/${license_file_name}."

		exit 1
	elif ! grep --quiet "docker@liferay.com" "${license_dir}/deploy/${license_file_name}"
	then
		echo "Invalid trial ${product_name^^} license exists at ${license_dir}/deploy/${license_file_name}."

		exit 1
	else
		echo "Valid trial ${product_name^^} license exists at ${license_dir}/deploy/${license_file_name}."
	fi
}

main "${@}"