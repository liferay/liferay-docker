#!/bin/bash

function trigger_ci_test_suite {
	if [ "${TRIGGER_CI_TEST_SUITE}" = "true" ]
	then
		local release_url="https://releases.liferay.com/dxp/release-candidates/"

		local http_response=$(curl \
			"http://test-1-1/job/test-portal-release/buildWithParameters" \
			--data-urlencode "CI_TEST_SUITE=${CI_TEST_SUITE}" \
			--data-urlencode "RUN_SCANCODE_PIPELINE=${RUN_SCANCODE_PIPELINE}" \
			--data-urlencode "TEST_PORTAL_BRANCH_NAME=$(_get_test_portal_branch_name "${LIFERAY_RELEASE_GIT_REF}")" \
			--data-urlencode "TEST_PORTAL_USER_BRANCH_NAME=${LIFERAY_RELEASE_GIT_REF}" \
			--data-urlencode "TEST_PORTAL_USER_NAME=brianchandotcom" \
			--data-urlencode "TEST_PORTAL_BUILD_PROFILE=${LIFERAY_RELEASE_PRODUCT_NAME}" \
			--data-urlencode "TEST_PORTAL_RELEASE_GIT_ID=${_GIT_SHA}" \
			--data-urlencode "TEST_PORTAL_RELEASE_OSGI_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-osgi-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" \
			--data-urlencode "TEST_PORTAL_RELEASE_SQL_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-sql-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" \
			--data-urlencode "TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z" \
			--data-urlencode "TEST_PORTAL_RELEASE_TOOLS_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-tools-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" \
			--data-urlencode "TEST_PORTAL_RELEASE_WAR_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.war" \
			--data-urlencode "TEST_PORTAL_RELEASE_VERSION=${_PRODUCT_VERSION}" \
			--fail \
			--max-time 10 \
			--request "POST" \
			--retry 3 \
			--silent \
			--user "${LIFERAY_RELEASE_JENKINS_USER}:${JENKINS_API_TOKEN}" \
			--write-out "%{http_code}")

		if [ "${http_response}" == "201" ]
		then
			lc_log INFO "Test build triggered."
		else
			lc_log ERROR "Unable to trigger the test build."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	else
		lc_log INFO "Skipping the test build job."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function _get_test_portal_branch_name {
	local branch_name="${1}"

	if [[ "${branch_name}" =~ ^7.4.* ]]
	then
		echo "master"
	else
		echo "${branch_name}"
	fi
}