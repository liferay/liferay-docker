#!/bin/bash

function get_product_group_version {
	echo "$(_get_product_version "${1}")" | cut --delimiter '.' --fields 1,2
}

function get_release_patch_version {
	local product_version="$(_get_product_version "${1}")"

	if is_lts_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter '.' --fields 3 | sed --expression "s/-lts//"
	else
		echo "${product_version}" | cut --delimiter '.' --fields 3
	fi
}

function get_release_quarter {
	echo "$(_get_product_version "${1}")" | cut --delimiter '.' --fields 2 | tr -d 'q'
}

function get_release_version {
	local product_version="$(_get_product_version "${1}")"

	if is_ga_release "${product_version}"
	then
		if is_7_3_ga_release "${product_version}"
		then
			echo "${product_version}" | cut --delimiter '.' --fields 1,2,3 | cut --delimiter '-' --fields 1
		else
			echo "${product_version}" | cut --delimiter '.' --fields 1,2,3
		fi
	elif is_u_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter '-' --fields 1
	fi
}

function get_release_version_trivial {
	local product_version="$(_get_product_version "${1}")"

	if is_ga_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter '-' --fields 2 | sed 's/ga//'
	elif is_u_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter '-' --fields 2 | tr -d u
	fi
}

function get_release_year {
	echo "$(_get_product_version "${1}")" | cut --delimiter '.' --fields 1
}

function has_ssh_connection {
	ssh "root@${1}" "exit" &> /dev/null

	if [ "${?}" -eq 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
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

function is_dxp_release {
	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "dxp" ]
	then
		return 0
	fi

	return 1
}

function is_early_product_version_than {
	_compare_product_versions "${1}" "early"
}

function is_ga_release {
	if [[ "$(_get_product_version "${1}")" == *-ga* ]]
	then
		return 0
	fi

	return 1
}

function is_later_product_version_than {
	_compare_product_versions "${1}" "later"
}

function is_lts_release {
	if [[ "$(_get_product_version "${1}")" == *lts* ]]
	then
		return 0
	fi

	return 1
}

function is_nightly_release {
	if [[ "$(_get_product_version "${1}")" == *nightly ]]
	then
		return 0
	fi

	return 1
}

function is_portal_release {
	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "portal" ]
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

function _compare_product_versions {
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

	local operator_1
	local operator_2

	if [ "${2}" == "early" ]
	then
		operator_1="-lt"
		operator_2="-gt"
	elif [ "${2}" == "later" ]
	then
		operator_1="-gt"
		operator_2="-lt"
	fi

	if [ "${product_version_1_year}" "${operator_1}" "${product_version_2_year}" ]
	then
		return 0
	elif [ "${product_version_1_year}" "${operator_2}" "${product_version_2_year}" ]
	then
		return 1
	fi

	if [ "${product_version_1_quarter}" "${operator_1}" "${product_version_2_quarter}" ]
	then
		return 0
	elif [ "${product_version_1_quarter}" "${operator_2}" "${product_version_2_quarter}" ]
	then
		return 1
	fi

	if [ "${product_version_1_suffix}" "${operator_1}" "${product_version_2_suffix}" ]
	then
		return 0
	elif [ "${product_version_1_suffix}" "${operator_2}" "${product_version_2_suffix}" ]
	then
		return 1
	fi

	return 1
}

function _get_product_version {
	if [ -n "${_PRODUCT_VERSION}" ] && [ -z "${1}" ]
	then
		echo "${_PRODUCT_VERSION}"
	else
		echo "${1}"
	fi
}