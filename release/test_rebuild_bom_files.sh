#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./rebuild_bom_files.sh

function main {
	set_up

	if [ -d "${_PROJECTS_DIR}/liferay-portal-ee" ]
	then
		if [ "${#}" -eq 1 ]
		then
			"${1}"
		else
			test_rebuild_bom_files_checkout_product_version
		fi
	else
		echo -e "The directory ${_PROJECTS_DIR}/liferay-portal-ee does not exist.\n"
	fi

	tear_down
}

function set_up {
	export _RELEASE_ROOT_DIR="${PWD}"

	export _PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/../..
}

function tear_down {
	unset _PROJECTS_DIR
	unset _RELEASE_ROOT_DIR
}

function test_rebuild_bom_files_checkout_product_version {
	_test_rebuild_bom_files_checkout_product_version "2025.q1.14-lts" "2025.q1.14"
	_test_rebuild_bom_files_checkout_product_version "2025.q2.3" "2025.q2.3"

	lc_cd "${_RELEASE_ROOT_DIR}"
}

function _test_rebuild_bom_files_checkout_product_version {
	_PRODUCT_VERSION="${1}"

	checkout_product_version &> /dev/null

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	assert_equals "$(git rev-parse --abbrev-ref HEAD)" "${2}"
}

main "${@}"