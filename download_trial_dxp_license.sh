#!/bin/bash

function main {
	local license_dir=${1}
	local license_start_date=${2}
	local release_file_name=${3}

	if [[ ${release_file_name} == *-commerce-enterprise-* ]] || [[ ${release_file_name} == *-dxp-* ]]
	then
		if [ -z "${LIFERAY_DOCKER_LICENSE_CMD}" ]
		then
			echo "Set the environment variable LIFERAY_DOCKER_LICENSE_CMD to generate a trial DXP license."

			exit 1
		else
			mkdir -p ${license_dir}/deploy

			local license_file_name=trial-dxp-license-${license_start_date}.xml

			eval "curl --silent --header \"${LIFERAY_DOCKER_LICENSE_CMD}?licenseLifetime=$(expr 1000 \* 60 \* 60 \* 24 \* 90)&startDate=${license_start_date}&owner=docker%40liferay.com\" > ${license_dir}/deploy/${license_file_name}"

			cat ${license_dir}/deploy/${license_file_name} |
				sed "s/\\\n//g" |
				sed "s/\\\t//g" |
				sed "s/\"<?xml/<?xml/" |
				sed "s/license>\"/license>/" |
				sed 's/\\"/\"/g' |
				sed 's/\\\//\//g' > ${license_dir}/deploy/${license_file_name}

			if [ ! -e ${license_dir}/deploy/${license_file_name} ]
			then
				echo "Trial DXP license does not exist at ${license_dir}/deploy/${license_file_name}."

				exit 1
			elif ! grep -q "docker@liferay.com" ${license_dir}/deploy/${license_file_name}
			then
				echo "Invalid trial DXP license exists at ${license_dir}/deploy/${license_file_name}."

				exit 1
			else
				echo "Valid Trial DXP license exists at ${license_dir}/deploy/${license_file_name}."
			fi
		fi
	fi

	if [[ ${release_file_name} == *-commerce-enterprise-* ]]
	then
		if [ -z "${LIFERAY_DOCKER_COMMERCE_LICENSE_CMD}" ]
		then
			echo "Set the environment variable LIFERAY_DOCKER_COMMERCE_LICENSE_CMD to generate a trial Commerce license."

			exit 1
		else
			mkdir -p ${license_dir}/data/license

			local commerce_license_file_name=trial-commerce-enterprise-license-${license_start_date}.li

			eval "curl --silent --header \"${LIFERAY_DOCKER_COMMERCE_LICENSE_CMD}?licenseLifetime=$(expr 1000 \* 60 \* 60 \* 24 \* 90)&startDate=${license_start_date}&owner=docker%40liferay.com\" > ${license_dir}/data/license/${commerce_license_file_name}"

			sed -i 's/["]//g' ${license_dir}/data/license/${commerce_license_file_name}

			if [ ! -e ${license_dir}/data/license/${commerce_license_file_name} ]
			then
				echo "Trial Commerce license does not exist at ${license_dir}/data/license/${commerce_license_file_name}."

				exit 1
			elif ! grep -q "docker@liferay.com" ${license_dir}/deploy/${commerce_license_file_name}
			then
				echo "Invalid trial DXP license exists at ${license_dir}/deploy/${commerce_license_file_name}."

				exit 1
			else
				echo "Valid trial Commerce license exists at ${license_dir}/data/license/${commerce_license_file_name}."
			fi
		fi
	fi
}

main ${@}