#!/bin/bash

function main {
	local license_dir=${1}
	local license_start_date=${2}

	if [ -z "${LIFERAY_DOCKER_LICENSE_API_HEADER}" ]
	then
		echo "Set the environment variable LIFERAY_DOCKER_LICENSE_API_HEADER to generate a trial DXP license."

		exit 1
	elif [ -z "${LIFERAY_DOCKER_LICENSE_API_URL}" ]
	then
		echo "Set the environment variable LIFERAY_DOCKER_LICENSE_API_URL to generate a trial DXP license."

		exit 1
	else
		mkdir -p "${license_dir}/deploy"

		local license_file_name="trial-dxp-license-${license_start_date}.xml"

		curl --header "${LIFERAY_DOCKER_LICENSE_API_HEADER}" --silent "${LIFERAY_DOCKER_LICENSE_API_URL}?licenseLifetime=$((1000 *60 * 60 * 24 * 90))&startDate=${license_start_date}&owner=docker%40liferay.com" > "${license_dir}/deploy/${license_file_name}.json"

		sed "s/\\\n//g" "${license_dir}/deploy/${license_file_name}.json" |
		sed "s/\\\t//g" |
		sed "s/\"<?xml/<?xml/" |
		sed "s/license>\"/license>/" |
		sed 's/\\"/\"/g' |
		sed 's/\\\//\//g' > "${license_dir}/deploy/${license_file_name}"

		rm -f "${license_dir}/deploy/${license_file_name}.json"

		if [ ! -e "${license_dir}/deploy/${license_file_name}" ]
		then
			echo "Trial DXP license does not exist at ${license_dir}/deploy/${license_file_name}."

			exit 1
		elif ! grep -q "docker@liferay.com" "${license_dir}/deploy/${license_file_name}"
		then
			echo "Invalid trial DXP license exists at ${license_dir}/deploy/${license_file_name}."

			exit 1
		else
			echo "Valid Trial DXP license exists at ${license_dir}/deploy/${license_file_name}."
		fi
	fi
}

main "${@}"
