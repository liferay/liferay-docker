#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./_ci.sh

function main {
	set_up

	if [[ "${#}" -eq 1 ]]
	then
		"${1}"
	else
		test_ci_get_test_portal_branch_name
		test_ci_get_test_portal_release_parameters
		test_ci_not_trigger_ci_test_suite
	fi

	tear_down
}

function set_up {
	export CI_JENKINS_API_KEY=""
	export LIFERAY_AI_HUB_RELEASE="false"
	export TRIGGER_CI_TEST_SUITE="false"
}

function tear_down {
	unset CI_JENKINS_API_KEY
	unset LIFERAY_AI_HUB_RELEASE
	unset TRIGGER_CI_TEST_SUITE
}

function test_ci_get_test_portal_branch_name {
	_test_ci_get_test_portal_branch_name "release-2025.q1" "release-2025.q1"
	_test_ci_get_test_portal_branch_name "release-7.4.13.135" "master"
	_test_ci_get_test_portal_branch_name "release-7.4.3.132-ga132" "master"

	LIFERAY_AI_HUB_RELEASE="true"

	_test_ci_get_test_portal_branch_name "release-ai-hub" "master"
}

function test_ci_get_test_portal_release_parameters {
	_BUILD_TIMESTAMP="1234567890"
	_PRODUCT_VERSION="2026.q1.0-lts"

	local release_url="https://storage.cloud.google.com/liferay-releases-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/"

	_test_ci_get_test_portal_release_parameters "$(cat <<- END
		--data-urlencode TEST_PORTAL_RELEASE_OSGI_URL=${release_url}liferay-dxp-osgi-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip
		--data-urlencode TEST_PORTAL_RELEASE_SQL_URL=${release_url}liferay-dxp-sql-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip
		--data-urlencode TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}liferay-dxp-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z
		--data-urlencode TEST_PORTAL_RELEASE_TOOLS_URL=${release_url}liferay-dxp-tools-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip
		--data-urlencode TEST_PORTAL_RELEASE_WAR_URL=${release_url}liferay-dxp-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.war
		END
	)"

	LIFERAY_RELEASE_CMS_STANDALONE="true"
	_PRODUCT_VERSION="7.4.13-u154-cms-standalone"

	release_url="https://storage.cloud.google.com/liferay-releases-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/"

	_test_ci_get_test_portal_release_parameters "$(cat <<- END
		--data-urlencode TEST_PORTAL_RELEASE_STANDALONE=true
		--data-urlencode TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}liferay-cms-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z
		END
	)"

	unset LIFERAY_RELEASE_CMS_STANDALONE
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
}

function test_ci_not_trigger_ci_test_suite {
	_test_ci_not_trigger_ci_test_suite "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"

	TRIGGER_CI_TEST_SUITE="true"

	_test_ci_not_trigger_ci_test_suite "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function _test_ci_get_test_portal_branch_name {
	assert_equals "$(_get_test_portal_branch_name "${1}")" "${2}"
}

function _test_ci_get_test_portal_release_parameters {
	assert_equals "$(_get_test_portal_release_parameters)" "${1}"
}

function _test_ci_not_trigger_ci_test_suite {
	trigger_ci_test_suite &> /dev/null

	assert_equals "${?}" "${1}"
}

main "${@}"