#!/bin/bash

function is_early_product_version_than {
	local product_version_1=$(echo "${ACTUAL_PRODUCT_VERSION}" | sed -e "s/-lts//")
	local product_version_1_quarter
	local product_version_1_suffix

	IFS='.' read -r product_version_1_year product_version_1_quarter product_version_1_suffix <<< "${product_version_1}"

	product_version_1_quarter=$(echo "${product_version_1_quarter}" | sed -e "s/q//")

	local product_version_2=$(echo "${1}" | sed -e "s/-lts//")
	local product_version_2_quarter
	local product_version_2_suffix

	IFS='.' read -r product_version_2_year product_version_2_quarter product_version_2_suffix <<< "${product_version_2}"

	product_version_2_quarter=$(echo "${product_version_2_quarter}" | sed -e "s/q//")

	if [ "${product_version_1_year}" -lt "${product_version_2_year}" ]
	then
		return 0
	elif [ "${product_version_1_year}" -gt "${product_version_2_year}" ]
	then
		return 1
	fi

	if [ "${product_version_1_quarter}" -lt "${product_version_2_quarter}" ]
	then
		return 0
	elif [ "${product_version_1_quarter}" -gt "${product_version_2_quarter}" ]
	then
		return 1
	fi

	if [ "${product_version_1_suffix}" -lt "${product_version_2_suffix}" ]
	then
		return 0
	elif [ "${product_version_1_suffix}" -gt "${product_version_2_suffix}" ]
	then
		return 1
	fi

	return 1
}

function is_quarterly_release {
	if [[ "${1}" == *q* ]]
	then
		return 0
	else
		return 1
	fi
}

function set_actual_product_version {
	ACTUAL_PRODUCT_VERSION="${1}"
}