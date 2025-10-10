#!/bin/bash

function get_latest_product_version {
	local product_name=""
	local product_version="${1}"
	local product_version_regex="(?<=<a href=\")"

	if [ "${product_version}" == "dxp" ]
	then
		product_name="dxp"
		product_version_regex="${product_version_regex}(7\.3\.10-u\d+)"
	elif [ "${product_version}" == "ga" ]
	then
		product_name="portal"
		product_version_regex="${product_version_regex}(7\.4\.3\.\d+-ga\d+)"
	elif [ "${product_version}" == "lts" ]
	then
		product_name="dxp"
		product_version_regex="${product_version_regex}(\d{4}\.q1\.[0-9]+-lts)"
	elif [ "${product_version}" == "quarterly" ]
	then
		product_name="dxp"
		product_version_regex="${product_version_regex}(\d{4}\.q[1-4]\.\d+(-lts)?)"
	elif [ "${product_version}" == "quarterly-candidate" ]
	then
		product_name="dxp/release-candidates"
		product_version_regex="${product_version_regex}(\d{4}\.q[1-4]\.\d+(-lts)?)"
	fi

	local product_version_list_html

	product_version_list_html=$(_download_product_version_list_html "${product_name}")

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download the product version list."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	echo "${product_version_list_html}" | \
		grep \
			--only-matching \
			--perl-regexp \
			"${product_version_regex}" | \
		tail --lines=1
}

function get_latest_version_from_url {
	curl "${1}" \
		--max-time 10 \
		--retry 2 \
		--silent \
		| grep --only-matching --perl-regexp "${2}" \
		| sort --version-sort \
		| tail --lines=1
}

function get_product_group_version {
	echo "$(_get_product_version "${1}")" | cut --delimiter='.' --fields=1,2
}

function get_product_version_without_lts_suffix {
	local product_version=$(_get_product_version "${1}")

	if is_quarterly_release "${product_version}"
	then
		echo "${product_version}" | sed "s/-lts//g"
	else
		echo "${product_version}"
	fi
}

function get_release_output {
	if [ -z "${LIFERAY_RELEASE_OUTPUT}" ]
	then
		LIFERAY_RELEASE_OUTPUT="release-candidate"
	fi

	echo "${LIFERAY_RELEASE_OUTPUT}"
}

function get_release_patch_version {
	local product_version="$(_get_product_version "${1}")"

	if is_lts_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter='.' --fields=3 | sed --expression "s/-lts//"
	else
		echo "${product_version}" | cut --delimiter='.' --fields=3
	fi
}

function get_release_quarter {
	echo "$(_get_product_version "${1}")" | cut --delimiter='.' --fields=2 | tr --delete 'q'
}

function get_release_version {
	local product_version="$(_get_product_version "${1}")"

	if is_ga_release "${product_version}"
	then
		if is_7_3_ga_release "${product_version}"
		then
			echo "${product_version}" | cut --delimiter='.' --fields=1,2,3 | cut --delimiter='-' --fields=1
		else
			echo "${product_version}" | cut --delimiter='.' --fields=1,2,3
		fi
	elif is_u_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter='-' --fields=1
	elif is_quarterly_release "${product_version}"
	then
		echo "${product_version}"
	fi
}

function get_release_version_trivial {
	local product_version="$(_get_product_version "${1}")"

	if is_ga_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter='-' --fields=2 | sed "s/ga//"
	elif is_u_release "${product_version}"
	then
		echo "${product_version}" | cut --delimiter='-' --fields=2 | tr --delete 'u'
	fi
}

function get_release_year {
	echo "$(_get_product_version "${1}")" | cut --delimiter='.' --fields=1
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

function is_first_quarterly_release {
	if is_quarterly_release && [[ "$(get_release_patch_version)" -eq 0 ]]
	then
		return 0
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

function is_later_product_version_than {
	_compare_product_versions "${1}" "later"
}

function is_lts_release {
	if [[ "$(_get_product_version "${1}")" == *lts ]]
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

function is_release_candidate {
	if [ "${LIFERAY_DOCKER_RELEASE_CANDIDATE}" == "true" ]
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

	local product_version_1

	if [ -n "${ACTUAL_PRODUCT_VERSION}" ]
	then
		product_version_1="${ACTUAL_PRODUCT_VERSION}"
	else
		product_version_1=$(_get_product_version)
	fi

	local product_version_2="${1}"

	if (is_ga_release "${product_version_1}" && is_ga_release "${product_version_2}") ||
	   (is_u_release "${product_version_1}" && is_u_release "${product_version_2}")
	then
		if [ "$(get_release_version_trivial ${product_version_1})" "${operator_1}" "$(get_release_version_trivial ${product_version_2})" ]
		then
			return 0
		elif [ "$(get_release_version_trivial ${product_version_1})" "${operator_2}" "$(get_release_version_trivial ${product_version_2})" ]
		then
			return 1
		fi
	elif is_quarterly_release "${product_version_1}" &&
		 is_quarterly_release "${product_version_2}"
	then
		if [ "$(get_release_year ${product_version_1})" "${operator_1}" "$(get_release_year ${product_version_2})" ]
		then
			return 0
		elif [ "$(get_release_year ${product_version_1})" "${operator_2}" "$(get_release_year ${product_version_2})" ]
		then
			return 1
		fi

		if [ "$(get_release_quarter ${product_version_1})" "${operator_1}" "$(get_release_quarter ${product_version_2})" ]
		then
			return 0
		elif [ "$(get_release_quarter ${product_version_1})" "${operator_2}" "$(get_release_quarter ${product_version_2})" ]
		then
			return 1
		fi

		if [ "$(get_release_patch_version ${product_version_1})" "${operator_1}" "$(get_release_patch_version ${product_version_2})" ]
		then
			return 0
		elif [ "$(get_release_patch_version ${product_version_1})" "${operator_2}" "$(get_release_patch_version ${product_version_2})" ]
		then
			return 1
		fi
	fi

	return 1
}

function _download_product_version_list_html {
	local product_version_list_html=""

	if [ "${LIFERAY_RELEASE_TEST_MODE}" == "true" ]
	then
		product_version_list_html=$(cat "${_RELEASE_ROOT_DIR}/test-dependencies/actual/$(basename "${1}").html")
	else
		product_version_list_html=$(lc_curl "https://releases.liferay.com/${1}/")
	fi

	if [ "${?}" -ne 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	echo "${product_version_list_html}"
}

function _get_product_version {
	if [ -n "${_PRODUCT_VERSION}" ] && [ -z "${1}" ]
	then
		echo "${_PRODUCT_VERSION}"
	else
		echo "${1}"
	fi
}