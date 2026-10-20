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
		test_ci_trigger_ci_test_suite
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

	LIFERAY_CMS_STANDALONE_RELEASE="true"

	_test_ci_get_test_portal_release_parameters "$(cat <<- END
		--data-urlencode TEST_PORTAL_RELEASE_STANDALONE=true
		--data-urlencode TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}liferay-dxp-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z
		END
	)"

	unset LIFERAY_CMS_STANDALONE_RELEASE
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
}

function test_ci_not_trigger_ci_test_suite {
	_test_ci_not_trigger_ci_test_suite "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"

	TRIGGER_CI_TEST_SUITE="true"

	_test_ci_not_trigger_ci_test_suite "${LIFERAY_COMMON_EXIT_CODE_BAD}"
}

function test_ci_trigger_ci_test_suite {
	CI_JENKINS_API_KEY="test"
	TRIGGER_CI_TEST_SUITE="true"
	_BUILD_TIMESTAMP="1234567890"
	_PRODUCT_VERSION="2026.q1.0-lts"

	local release_url="https://storage.cloud.google.com/liferay-releases-candidates/${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}/"

	_test_ci_trigger_ci_test_suite "$(cat <<- END
		TEST_PORTAL_RELEASE_GIT_ID=
		TEST_PORTAL_RELEASE_OSGI_URL=${release_url}liferay-dxp-osgi-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip
		TEST_PORTAL_RELEASE_SQL_URL=${release_url}liferay-dxp-sql-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip
		TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}liferay-dxp-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z
		TEST_PORTAL_RELEASE_TOOLS_URL=${release_url}liferay-dxp-tools-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.zip
		TEST_PORTAL_RELEASE_VERSION=${_PRODUCT_VERSION}
		TEST_PORTAL_RELEASE_WAR_URL=${release_url}liferay-dxp-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.war
		END
	)"

	LIFERAY_CMS_STANDALONE_RELEASE="true"

	_test_ci_trigger_ci_test_suite "$(cat <<- END
		TEST_PORTAL_RELEASE_GIT_ID=
		TEST_PORTAL_RELEASE_STANDALONE=true
		TEST_PORTAL_RELEASE_TOMCAT_URL=${release_url}liferay-dxp-tomcat-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.7z
		TEST_PORTAL_RELEASE_VERSION=${_PRODUCT_VERSION}
		END
	)"

	unset CI_JENKINS_API_KEY
	unset LIFERAY_CMS_STANDALONE_RELEASE
	unset TRIGGER_CI_TEST_SUITE
	unset _BUILD_TIMESTAMP
	unset _PRODUCT_VERSION
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

function _test_ci_trigger_ci_test_suite {
	local curl_stub_dir=$(mktemp --directory)

	local curl_arguments_file="${curl_stub_dir}/curl_arguments"

	cat > "${curl_stub_dir}/curl" <<- END
		#!/bin/bash

		printf "%s\\n" "\${@}" > "${curl_arguments_file}"

		echo "201"
	END

	chmod +x "${curl_stub_dir}/curl"

	PATH="${curl_stub_dir}:${PATH}" trigger_ci_test_suite &> /dev/null

	assert_equals \
		"$(grep "^TEST_PORTAL_RELEASE_" "${curl_arguments_file}" | sort)" \
		"${1}"

	rm --force --recursive "${curl_stub_dir}"
}

main "${@}"