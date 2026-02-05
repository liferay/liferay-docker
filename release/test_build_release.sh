#!/bin/bash

source ../_test_common.sh
source ./build_release.sh

function main {
	set_up

	test_build_release_main

	if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
	then
		tear_down

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	test_build_release_bundle_smaller_than_1_gb_300_mb
	test_build_release_handle_automated_build
	test_build_release_has_packaged_bundles
	test_build_release_not_handle_automated_build
	test_build_release_print_help

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_GIT_REF="release-test"
	export RUN_SCANCODE_PIPELINE="false"
	export TRIGGER_CI_TEST_SUITE="false"
	export _PRODUCT_VERSION="2025.q4.1"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _RELEASE_PACKAGE="${_RELEASE_ROOT_DIR}/release-data/build/release"
}

function tear_down {
	common_tear_down

	rm --force --recursive "${_RELEASE_ROOT_DIR}/release-data"

	unset LIFERAY_RELEASE_GIT_REF
	unset RUN_SCANCODE_PIPELINE
	unset TRIGGER_CI_TEST_SUITE
	unset _RELEASE_PACKAGE
	unset _RELEASE_ROOT_DIR
}

function test_build_release_bundle_smaller_than_1_gb_300_mb {
	assert_equals \
		"$(( $(stat --format="%s" "${_RELEASE_PACKAGE}"/liferay-dxp-tomcat-2025.q4.1-*.7z) < 1300000000 ))" \
		"1"
}

function test_build_release_handle_automated_build {
	BUILD_CAUSE="TIMERTRIGGER"

	handle_automated_build &> /dev/null

	assert_equals \
		"${LIFERAY_RELEASE_GIT_REF}" \
		"release-2025.q2" \
		"${RUN_SCANCODE_PIPELINE}" \
		"true" \
		"${TRIGGER_CI_TEST_SUITE}" \
		"true"

	unset BUILD_CAUSE
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

function test_build_release_not_handle_automated_build {
	_test_build_release_not_handle_automated_build "hotfix" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	_test_build_release_not_handle_automated_build "nightly" "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"

	BUILD_CAUSE="TIMERTRIGGER"

	local latest_release_candidate=$(
		cat <<- END
		<li>
			<a href="/dxp/release-candidates/2025.q2.9-1754280641" class="icon icon-directory" title="2025.q2.9-1754280641">
				<span class="name">2025.q2.9-1754280641</span>
				<span class="size"></span>
				<span class="date">12/23/2025 12:32:16 PM</span>
			</a>
		</li>
		END
	)

	latest_release_candidate="${latest_release_candidate//$'\n'/\\n}"

	sed --in-place "/<\/ul>/i \\${latest_release_candidate}" test-dependencies/actual/release-candidates.html

	_test_build_release_not_handle_automated_build "release-candidate" "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	git restore test-dependencies/actual/release-candidates.html

	unset BUILD_CAUSE
}

function test_build_release_main {
	LIFERAY_RELEASE_GIT_REF=2025.q4.1 ./build_release.sh

	local exit_code="${?}"

	assert_equals "${exit_code}" "0"

	if [ "${exit_code}" -ne 0 ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function test_build_release_print_help {
	_test_build_release_print_help "2025.q1.0-lts"
	_test_build_release_print_help "2025.q2.0"
	_test_build_release_print_help "2025.q3.0"
	_test_build_release_print_help "2025.q4.0"
}

function _test_build_release_not_handle_automated_build {
	LIFERAY_RELEASE_OUTPUT="${1}"

	handle_automated_build &> /dev/null

	assert_equals "${?}" "${2}"
}

function _test_build_release_print_help {
	_PRODUCT_VERSION="${1}"

	LIFERAY_RELEASE_GIT_REF="${_PRODUCT_VERSION}" ./build_release.sh &> /dev/null

	assert_equals "${?}" "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main