#!/bin/bash

function get_product_group_version {
	if [ -n "${_PRODUCT_VERSION}" ]
	then
		echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1,2
	else
		echo "${1}" | cut -d '.' -f 1,2
	fi
}

function get_release_quarter {
	if [ -n "${_PRODUCT_VERSION}" ]
	then
		echo "${_PRODUCT_VERSION}" | cut -d '.' -f 2 | tr -d 'q'
	else
		echo "${1}" | cut -d '.' -f 2 | tr -d 'q'
	fi
}

function get_release_year {
	if [ -n "${_PRODUCT_VERSION}" ]
	then
		echo "${_PRODUCT_VERSION}" | cut -d '.' -f 1
	else
		echo "${1}" | cut -d '.' -f 1
	fi
}

function is_7_3_ga_release {
	if [[ "$(_get_product_version "${1}")" == 7.3.*-ga* ]]
	then
		return 0
	fi

	return 1
}

function is_7_3_release {
	if [[ "$(_get_product_version "${1}")" == 7.3* ]]
	then
		return 0
	fi

	return 1
}

function is_7_3_u_release {
	if [[ "$(_get_product_version "${1}")" == 7.3.*-u* ]]
	then
		return 0
	fi

	return 1
}

function is_7_4_ga_release {
	if [[ "$(_get_product_version "${1}")" == 7.4.*-ga* ]]
	then
		return 0
	fi

	return 1
}

function is_7_4_release {
	if [[ "$(_get_product_version "${1}")" == 7.4* ]]
	then
		return 0
	fi

	return 1
}

function is_7_4_u_release {
	if [[ "$(_get_product_version "${1}")" == 7.4.*-u* ]]
	then
		return 0
	fi

	return 1
}

function is_early_product_version_than {
	local product_version_1=""

	if [ -n "${ACTUAL_PRODUCT_VERSION}" ]
	then
		product_version_1=$(echo "${ACTUAL_PRODUCT_VERSION}" | sed -e "s/-lts//")
	else
		product_version_1=$(_get_product_version | sed -e "s/-lts//")
	fi

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

function is_ga_release {
	if [[ "$(_get_product_version "${1}")" == *-ga* ]]
	then
		return 0
	fi

	return 1
}

function is_lts_release {
	if [[ "$(_get_product_version "${1}")" == *lts* ]]
	then
		return 0
	fi

	return 1
}

function is_quarterly_release {
	if [[ "$(_get_product_version "${1}")" == *q* ]]
	then
		return 0
	fi

	return 1
}

function is_u_release {
	if [[ "$(_get_product_version "${1}")" == *-u* ]]
	then
		return 0
	fi

	return 1
}

function set_actual_product_version {
	ACTUAL_PRODUCT_VERSION="${1}"
}

function _get_product_version {
	if [ -n "${_PRODUCT_VERSION}" ] && [ -z "${1}" ]
	then
		echo "${_PRODUCT_VERSION}"
	else
		echo "${1}"
	fi
}