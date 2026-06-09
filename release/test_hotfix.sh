#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_hotfix.sh

function main {
	set_up

	test_hotfix_compare_jars

	tear_down
}

function set_up {
	export _BUILD_DIR=$(mktemp --directory)
	export _BUNDLES_DIR="${_BUILD_DIR}/bundles"
	export _RELEASE_DIR="${_BUILD_DIR}/release"

	mkdir --parents "${_BUNDLES_DIR}/osgi/modules" "${_RELEASE_DIR}/osgi/modules"

	_create_module_jar "${_BUNDLES_DIR}/osgi/modules/com.liferay.test.changed.impl.jar" "new content" "2020-01-01 00:00:00" "17.0.14"
	_create_module_jar "${_RELEASE_DIR}/osgi/modules/com.liferay.test.changed.impl.jar" "original content" "2020-01-01 00:00:00" "17.0.14"
	_create_module_jar "${_BUNDLES_DIR}/osgi/modules/com.liferay.test.rebuilt.impl.jar" "original content" "2021-01-01 00:00:00" "17.0.14"
	_create_module_jar "${_RELEASE_DIR}/osgi/modules/com.liferay.test.rebuilt.impl.jar" "original content" "2020-01-01 00:00:00" "17.0.18"
}

function tear_down {
	rm --force --recursive "${_BUILD_DIR}"

	unset _BUILD_DIR
	unset _BUNDLES_DIR
	unset _RELEASE_DIR
}

function test_hotfix_compare_jars {
	_test_hotfix_compare_jars "osgi/modules/com.liferay.test.changed.impl.jar" "${LIFERAY_COMMON_EXIT_CODE_OK}"
	_test_hotfix_compare_jars "osgi/modules/com.liferay.test.rebuilt.impl.jar" "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function _create_module_jar {
	local packaged_jar_dir=$(mktemp --directory)

	echo "Liferay-Created-By: ${4}" > "${packaged_jar_dir}/manifest"

	echo "${2}" > "${packaged_jar_dir}/internal.txt"

	touch --date "${3}" "${packaged_jar_dir}/internal.txt"

	local module_jar_dir=$(mktemp --directory)

	mkdir --parents "${module_jar_dir}/lib"

	jar cfm "${module_jar_dir}/lib/internal.jar" "${packaged_jar_dir}/manifest" -C "${packaged_jar_dir}" internal.txt

	echo "external content" > "${module_jar_dir}/external.txt"

	touch --date "2020-01-01 00:00:00" "${module_jar_dir}/external.txt" "${module_jar_dir}/lib/internal.jar"

	jar cf "${1}" -C "${module_jar_dir}" external.txt -C "${module_jar_dir}" lib/internal.jar

	rm --force --recursive "${module_jar_dir}" "${packaged_jar_dir}"
}

function _test_hotfix_compare_jars {
	compare_jars "${1}" &> /dev/null

	assert_equals "${?}" "${2}"
}

main "${@}"