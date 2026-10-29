#!/bin/bash

source ../_liferay_common.sh
source ../_release_common.sh
source ../_test_common.sh
source ./_hotfix.sh

function main {
	set_up

	test_hotfix_compare_jars
	test_hotfix_prepare_release_dir
	test_hotfix_set_hotfix_name

	tear_down
}

function set_up {
	export _BUILD_DIR=$(mktemp --directory)
	export _BUNDLES_DIR="${_BUILD_DIR}/bundles"
	export _RELEASE_DIR="${_BUILD_DIR}/release"

	mkdir --parents "${_BUNDLES_DIR}/osgi/modules" "${_RELEASE_DIR}/osgi/modules"

	_create_module_jar "${_BUNDLES_DIR}/osgi/modules/com.liferay.test.changed.impl.jar" "new content" "2020-01-01 00:00:00" "17.0.14"
	_create_module_jar "${_BUNDLES_DIR}/osgi/modules/com.liferay.test.rebuilt.impl.jar" "original content" "2021-01-01 00:00:00" "17.0.14"
	_create_module_jar "${_RELEASE_DIR}/osgi/modules/com.liferay.test.changed.impl.jar" "original content" "2020-01-01 00:00:00" "17.0.14"
	_create_module_jar "${_RELEASE_DIR}/osgi/modules/com.liferay.test.rebuilt.impl.jar" "original content" "2020-01-01 00:00:00" "17.0.18"

	_create_portal_bootstrap_jar "${_BUNDLES_DIR}/osgi/modules/com.liferay.test.portal.bootstrap.changed.jar" "1772646511768" "2.20.0"
	_create_portal_bootstrap_jar "${_BUNDLES_DIR}/osgi/modules/com.liferay.test.portal.bootstrap.rebuilt.jar" "1772646599999" "2.17.1"
	_create_portal_bootstrap_jar "${_RELEASE_DIR}/osgi/modules/com.liferay.test.portal.bootstrap.changed.jar" "1772646511768" "2.17.1"
	_create_portal_bootstrap_jar "${_RELEASE_DIR}/osgi/modules/com.liferay.test.portal.bootstrap.rebuilt.jar" "1772646511768" "2.17.1"
}

function tear_down {
	rm --force --recursive "${_BUILD_DIR}"

	unset _BUILD_DIR
	unset _BUNDLES_DIR
	unset _RELEASE_DIR
}

function test_hotfix_compare_jars {
	_test_hotfix_compare_jars "osgi/modules/com.liferay.test.changed.impl.jar" "0"
	_test_hotfix_compare_jars "osgi/modules/com.liferay.test.portal.bootstrap.changed.jar" "0"
	_test_hotfix_compare_jars "osgi/modules/com.liferay.test.portal.bootstrap.rebuilt.jar" "1"
	_test_hotfix_compare_jars "osgi/modules/com.liferay.test.rebuilt.impl.jar" "1"
}

function test_hotfix_prepare_release_dir {
	_test_hotfix_prepare_release_dir "2026.q4.0" "liferay-dxp" "liferay-dxp-tomcat-2026.q4.0-1234567890"
	_test_hotfix_prepare_release_dir "2026.q4.0-cms-standalone" "liferay-cms" "liferay-cms-standalone-tomcat-2026.q4.0-1234567890"
}

function test_hotfix_set_hotfix_name {
	_test_hotfix_set_hotfix_name "2026.q4.0" "liferay-dxp-2026.q4.0-hotfix-12.zip"
	_test_hotfix_set_hotfix_name "2026.q4.0-cms-standalone" "liferay-cms-2026.q4.0-hotfix-12.zip"
	_test_hotfix_set_hotfix_name "2027.q1.0-lts" "liferay-dxp-2027.q1.0-lts-hotfix-12.zip"
	_test_hotfix_set_hotfix_name "2027.q1.0-lts-cms-standalone" "liferay-cms-2027.q1.0-lts-hotfix-12.zip"
	_test_hotfix_set_hotfix_name "7.4.13-u154" "liferay-dxp-7.4.13-u154-hotfix-12.zip"
}

function _create_module_jar {
	local packaged_jar_dir=$(mktemp --directory)

	echo "${2}" > "${packaged_jar_dir}/internal.txt"

	touch --date "${3}" "${packaged_jar_dir}/internal.txt"

	echo "Liferay-Created-By: ${4}" > "${packaged_jar_dir}/manifest"

	local module_jar_dir=$(mktemp --directory)

	mkdir --parents "${module_jar_dir}/lib"

	jar cfm "${module_jar_dir}/lib/internal.jar" "${packaged_jar_dir}/manifest" -C "${packaged_jar_dir}" internal.txt

	echo "external content" > "${module_jar_dir}/external.txt"

	touch --date "2020-01-01 00:00:00" "${module_jar_dir}/external.txt" "${module_jar_dir}/lib/internal.jar"

	jar cf "${1}" -C "${module_jar_dir}" external.txt -C "${module_jar_dir}" lib/internal.jar

	rm --force --recursive "${module_jar_dir}" "${packaged_jar_dir}"
}

function _create_portal_bootstrap_jar {
	local jar_dir=$(mktemp --directory)

	mkdir --parents "${jar_dir}/META-INF"

	(
		echo "Bnd-LastModified: ${2}"
		echo "Export-Package: org.apache.logging.log4j;version=\"${3}\",org.apa"
		echo " che.logging.log4j.spi;version=\"${3}\""
	) > "${jar_dir}/META-INF/system.packages.extra.mf"

	jar cf "${1}" -C "${jar_dir}" META-INF/system.packages.extra.mf

	rm --force --recursive "${jar_dir}"
}

function _test_hotfix_compare_jars {
	compare_jars "${1}" &> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_hotfix_prepare_release_dir {
	_PRODUCT_VERSION=${1}

	local release_file_dir=$(mktemp --directory)

	mkdir --parents "${release_file_dir}/${2}/tomcat"

	echo "test" > "${release_file_dir}/${2}/tomcat/test.txt"

	_RELEASES_DIR="${_BUILD_DIR}/releases"
	_TEST_RELEASE_DIR="${_BUILD_DIR}/test_release"

	mkdir --parents "${_TEST_RELEASE_DIR}"

	7z a "${_TEST_RELEASE_DIR}/${3}.7z" "${release_file_dir}/${2}" &> /dev/null

	(prepare_release_dir) &> /dev/null

	local liferay_dir_count=$( \
		find \
			"${_RELEASES_DIR}/${3}" \
			-maxdepth 1 \
			-mindepth 1 \
			-name "liferay-*" | \
		wc --lines)

	assert_equals \
		"$(cat "${_RELEASES_DIR}/${3}/tomcat/test.txt")" \
		"test" \
		"${liferay_dir_count}" \
		"0"

	rm \
		--force \
		--recursive \
		"${_RELEASES_DIR}" \
		"${_TEST_RELEASE_DIR}" \
		"${release_file_dir}"
}

function _test_hotfix_set_hotfix_name {
	_PRODUCT_VERSION=${1}

	LIFERAY_RELEASE_HOTFIX_ID="12"

	set_hotfix_name

	assert_equals \
		"${_HOTFIX_FILE_NAME}" \
		"${2}" \
		"${_HOTFIX_NAME}" \
		"hotfix-12"
}

main "${@}"