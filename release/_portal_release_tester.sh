#!/bin/bash

source _github.sh

function get_test_portal_branch_name {
    local branch_name=${1}

    if [[ "${branch_name}" =~ "7.4." ]]
    then
        echo "master"
    else
        echo "${branch_name}"
    fi
}

function send_to_ci_test {
	if [ "${SEND_BUILD_TO_TEST_CI}" = "true" ]
	then
		# Parameters
		local github_branch_name="$(get_test_portal_branch_name ${LIFERAY_RELEASE_GIT_REF})"
		local github_user_branch_name="${LIFERAY_RELEASE_GIT_REF}"
		local github_user_name="brianchandotcom"
		local git_commit_id="$(get_git_hash ${github_user_branch_name})"
		local release_url="https://releases.liferay.com/dxp/release-candidates/"
		local repo_name="liferay-portal-ee"
		# Trigger job
		if(curl -X POST "http://test-1-1/job/test-portal-release/buildWithParameters" \
			--user "${LIFERAY_RELEASE_JENKINS_USER}:${JENKINS_API_TOKEN}" \
			--data-urlencode "CI_TEST_SUITE=${CI_TEST_SUITE}" \
			--data-urlencode "RUN_SCANCODE_PIPELINE=${RUN_SCANCODE_PIPELINE}" \
			--data-urlencode "TEST_PORTAL_BRANCH_NAME=${github_branch_name}" \
			--data-urlencode "TEST_PORTAL_USER_BRANCH_NAME=${github_user_branch_name}" \
			--data-urlencode "TEST_PORTAL_USER_NAME=${github_user_name}" \
			--data-urlencode "TEST_PORTAL_BUILD_PROFILE=${LIFERAY_RELEASE_PRODUCT_NAME}" \
			--data-urlencode "TEST_PORTAL_RELEASE_GIT_ID=${git_commit_id}" \
			--data-urlencode "TEST_PORTAL_RELEASE_OSGI_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-osgi-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" \
			--data-urlencode "TEST_PORTAL_RELEASE_SQL_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-sql-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" \
			--data-urlencode "TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z" \
			--data-urlencode "TEST_PORTAL_RELEASE_TOOLS_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-tools-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip" \
			--data-urlencode "TEST_PORTAL_RELEASE_WAR_URL=${release_url}${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/liferay-dxp-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.war" \
			--data-urlencode "TEST_PORTAL_RELEASE_VERSION=${_PRODUCT_VERSION}" \
			--data-urlencode "TEST_PORTAL_REPOSITORY_NAME=${repo_name}")
		then
			lc_log INFO "Test build triggered."
		else
			lc_log ERROR "Unable to trigger the test build."
		fi
	else
		lc_log INFO "Skipping the test build job."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

}