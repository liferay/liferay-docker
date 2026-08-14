#!/bin/bash

source ../_test_common.sh
source ../test/_test_util.sh
source ./build_release.sh

function main {
	set_up

	trap tear_down EXIT

	test_build_release_main || exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	test_build_release_bundle_smaller_than_1_gb_300_mb
	test_build_release_handle_automated_build
	test_build_release_handle_automated_build_cms_standalone
	test_build_release_has_automated_build_failure_slack_message
	test_build_release_has_packaged_bundles
	test_build_release_has_slack_message
	test_build_release_not_handle_automated_build

	test_build_hotfix_main || exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	test_build_hotfix_has_packaged_hotfix

	_clean_up_release_data

	LIFERAY_RELEASE_GIT_REF="fix-pack-fix-263630758"
	_PRODUCT_VERSION="7.3.10-u36"

	test_build_hotfix_main || exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	test_build_hotfix_has_packaged_hotfix
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_GIT_REF="2025.q4.1"
	export LIFERAY_RELEASE_HOTFIX_ID="12345"
	export LIFERAY_RELEASE_TEST_ALTERNATIVE_PATH="${HOME}/.liferay/java"
	export LIFERAY_RELEASE_TEST_DEFAULT_PATH="/opt/java"
	export LIFERAY_RELEASE_TEST_MACHINE=$(uname --machine)
	export RUN_SCANCODE_PIPELINE="false"
	export TRIGGER_CI_TEST_SUITE="false"
	export _PRODUCT_VERSION="2025.q4.1"
	export _RELEASE_ROOT_DIR=${PWD}
	export _RELEASE_TOOL_DIR=$(mktemp --directory)

	export _RELEASE_PACKAGE="${_RELEASE_ROOT_DIR}/release-data/build/release"
}

function tear_down {
	common_tear_down

	_clean_up_release_data

	rm --force --recursive "${_RELEASE_TOOL_DIR}"

	unset LIFERAY_CMS_STANDALONE_RELEASE
	unset LIFERAY_RELEASE_GIT_REF
	unset LIFERAY_RELEASE_TEST_ALTERNATIVE_PATH
	unset LIFERAY_RELEASE_TEST_DATE
	unset LIFERAY_RELEASE_TEST_DEFAULT_PATH
	unset LIFERAY_RELEASE_TEST_MACHINE
	unset RUN_SCANCODE_PIPELINE
	unset TRIGGER_CI_TEST_SUITE
	unset _RELEASE_PACKAGE
	unset _RELEASE_ROOT_DIR
	unset _RELEASE_TOOL_DIR
}

function test_build_hotfix_has_packaged_hotfix {
	local hotfix_zip_file="${_RELEASE_ROOT_DIR}/release-data/build/liferay-dxp-${_PRODUCT_VERSION}-hotfix-${LIFERAY_RELEASE_HOTFIX_ID}.zip"

	assert_equals \
		"$(ls -1 "${hotfix_zip_file}" | wc --lines)" \
		"1"

	rm --force "${hotfix_zip_file}"
}

function test_build_hotfix_main {
	LIFERAY_RELEASE_OUTPUT="hotfix" ./build_release.sh &> /dev/null

	local exit_code=${?}

	assert_equals "${exit_code}" "0"

	if [[ "${exit_code}" -ne 0 ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function test_build_release_bundle_smaller_than_1_gb_300_mb {
	assert_equals \
		"$(($(stat --format="%s" "${_RELEASE_PACKAGE}"/liferay-dxp-tomcat-2025.q4.1-*.7z) < 1300000000))" \
		"1"
}

function test_build_release_handle_automated_build {
	BUILD_CAUSE="TIMERTRIGGER"
	LIFERAY_RELEASE_GIT_REF="release-test"
	LIFERAY_RELEASE_TEST_DATE="2026-08-10"

	handle_automated_build &> /dev/null

	assert_equals \
		"${LIFERAY_RELEASE_GIT_REF}" \
		"release-2025.q2" \
		"${RUN_SCANCODE_PIPELINE}" \
		"true" \
		"${TRIGGER_CI_TEST_SUITE}" \
		"true"

	unset BUILD_CAUSE
	unset LIFERAY_RELEASE_TEST_DATE

	LIFERAY_RELEASE_GIT_REF=${_PRODUCT_VERSION}
}

function test_build_release_handle_automated_build_cms_standalone {
	BUILD_CAUSE="TIMERTRIGGER"
	CI_TEST_SUITE="portal-release-acceptance"
	LIFERAY_RELEASE_GIT_REF="release-test"
	LIFERAY_RELEASE_TEST_DATE="2026-08-11"
	RUN_SCANCODE_PIPELINE="false"

	handle_automated_build &> /dev/null

	assert_equals \
		"${CI_TEST_SUITE}" \
		"portal-release-cms" \
		"${LIFERAY_CMS_STANDALONE_RELEASE}" \
		"true" \
		"${LIFERAY_RELEASE_GIT_REF}" \
		"master" \
		"${RUN_SCANCODE_PIPELINE}" \
		"false" \
		"${TRIGGER_CI_TEST_SUITE}" \
		"true"

	unset BUILD_CAUSE
	unset CI_TEST_SUITE
	unset LIFERAY_CMS_STANDALONE_RELEASE
	unset LIFERAY_RELEASE_TEST_DATE

	LIFERAY_RELEASE_GIT_REF=${_PRODUCT_VERSION}
}

function test_build_release_has_automated_build_failure_slack_message {
	BUILD_CAUSE="TIMERTRIGGER"
	LIFERAY_RELEASE_OUTPUT="release-candidate"
	LIFERAY_RELEASE_TEST_DATE="2026-08-10"

	add_release_to_test_dependency "2025.q2.9-1234567890" "test-dependencies/actual/release-candidates.html"

	handle_automated_build &> /dev/null

	git restore test-dependencies/actual/release-candidates.html

	local slack_message_file="${_RELEASE_TOOL_DIR}/build_release_slack_message.txt"

	assert_equals \
		"$(grep --count "^\*Automated build failed\*$" "${slack_message_file}")" \
		"1" \
		"$(grep --count "^\*Reason:\* The latest quarterly release candidate (\`2025.q2.9\`) has not been published\.$" "${slack_message_file}")" \
		"1" \
		"$(grep --count "^\*Latest published quarterly release product version:\* \`2025.q2.8\`$" "${slack_message_file}")" \
		"1"

	unset BUILD_CAUSE
	unset LIFERAY_RELEASE_OUTPUT
	unset LIFERAY_RELEASE_TEST_DATE
}

function test_build_release_has_packaged_bundles {
	assert_equals \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q4.1-*.7z" -type f | wc --lines)" \
		"1" \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q4.1-*.tar.gz" -type f | wc --lines)" \
		"1" \
		"$(find "${_RELEASE_PACKAGE}" -name "liferay-dxp-tomcat-2025.q4.1-*.zip" -type f | wc --lines)" \
		"1"
}

function test_build_release_has_slack_message {
	assert_equals \
		"$(grep --count "^\*Version:\* \`2025.q4.1-[0-9]*\`$" "${_RELEASE_ROOT_DIR}/build_release_slack_message.txt")" \
		"1"
}

function test_build_release_main {
	LIFERAY_RELEASE_GIT_REF="2025.q4.1" ./build_release.sh &> /dev/null

	local exit_code=${?}

	assert_equals "${exit_code}" "0"

	if [[ "${exit_code}" -ne 0 ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function test_build_release_not_handle_automated_build {
	_test_build_release_not_handle_automated_build "hotfix" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_release_not_handle_automated_build "nightly" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"

	BUILD_CAUSE="TIMERTRIGGER"
	LIFERAY_RELEASE_TEST_DATE="2026-08-10"

	add_release_to_test_dependency "2025.q2.9-1234567890" "test-dependencies/actual/release-candidates.html"

	_test_build_release_not_handle_automated_build "release-candidate" "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	git restore test-dependencies/actual/release-candidates.html

	unset BUILD_CAUSE
	unset LIFERAY_RELEASE_TEST_DATE
}

function _clean_up_release_data {
	pgrep --full --list-name "${_RELEASE_ROOT_DIR}/release-data" | \
		awk '{print $1}' | \
		xargs --no-run-if-empty kill -9

	rm --force --recursive "${_RELEASE_ROOT_DIR}/release-data"

	rm --force "${_RELEASE_ROOT_DIR}/build_release_slack_message.txt"
}

function _test_build_release_not_handle_automated_build {
	LIFERAY_RELEASE_OUTPUT=${1}

	handle_automated_build &> /dev/null

	assert_equals "${?}" "${2}"
}

main