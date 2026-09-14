#!/bin/bash

source ./_test_common.sh

function main {
	test_liferay_batch_entrypoint_import_task_status
	test_liferay_batch_entrypoint_polls_with_backoff
	test_liferay_batch_entrypoint_removes_the_items_file
	test_liferay_batch_entrypoint_reports_completed_with_failed_items
	test_liferay_batch_entrypoint_reports_poll_http_error
	test_liferay_batch_entrypoint_reports_post_error_body
	test_liferay_batch_entrypoint_reports_unparseable_poll_response
	test_liferay_batch_entrypoint_requires_oauth_app_erc
	test_liferay_batch_entrypoint_retries_transient_poll_failure
}

function set_up {
	common_set_up

	_TEST_FIXTURE_DIR=$(mktemp --directory)

	mkdir --parents \
		"${_TEST_FIXTURE_DIR}/batch" \
		"${_TEST_FIXTURE_DIR}/bin" \
		"${_TEST_FIXTURE_DIR}/tmp" \
		"${_TEST_FIXTURE_DIR}/lxc/dxp-metadata" \
		"${_TEST_FIXTURE_DIR}/lxc/ext-init-metadata"

	echo "localhost" > "${_TEST_FIXTURE_DIR}/lxc/dxp-metadata/com.liferay.lxc.dxp.main.domain"
	echo "http" > "${_TEST_FIXTURE_DIR}/lxc/dxp-metadata/com.liferay.lxc.dxp.server.protocol"
	echo "id" > "${_TEST_FIXTURE_DIR}/lxc/ext-init-metadata/test.oauth2.headless.server.client.id"
	echo "secret" > "${_TEST_FIXTURE_DIR}/lxc/ext-init-metadata/test.oauth2.headless.server.client.secret"
	echo "/o/oauth2/token" > "${_TEST_FIXTURE_DIR}/lxc/ext-init-metadata/test.oauth2.token.uri"

	echo "{\"configuration\": {\"className\": \"Foo\", \"parameters\": {\"createStrategy\": \"UPSERT\"}}, \"items\": [{\"name\": \"x\"}]}" > "${_TEST_FIXTURE_DIR}/batch/00-test.batch-engine-data.json"

	touch "${_TEST_FIXTURE_DIR}/poll_count"

	_write_curl_stub

	export _TEST_POLL_BODY="{\"executeStatus\": \"COMPLETED\", \"failedItems\": []}"
	export _TEST_POLL_COUNT_FILE="${_TEST_FIXTURE_DIR}/poll_count"
	export _TEST_POLL_HTTP_STATUS="200"
	export _TEST_POLL_TRANSIENT_BODY=""
	export _TEST_POLL_TRANSIENT_COUNT="0"
	export _TEST_POST_BODY="{\"externalReferenceCode\": \"ERC-1\"}"
	export _TEST_POST_HTTP_STATUS="200"
	export _TEST_TOKEN_BODY="{\"access_token\": \"token\", \"expires_in\": 600}"
	export _TEST_TOKEN_HTTP_STATUS="200"
}

function tear_down {
	common_tear_down

	rm --force --recursive "${_TEST_FIXTURE_DIR}"

	unset _TEST_ENTRYPOINT_EXIT_CODE
	unset _TEST_ENTRYPOINT_OUTPUT
	unset _TEST_FIXTURE_DIR
	unset _TEST_POLL_BODY
	unset _TEST_POLL_COUNT_FILE
	unset _TEST_POLL_HTTP_STATUS
	unset _TEST_POLL_TRANSIENT_BODY
	unset _TEST_POLL_TRANSIENT_COUNT
	unset _TEST_POST_BODY
	unset _TEST_POST_HTTP_STATUS
	unset _TEST_TOKEN_BODY
	unset _TEST_TOKEN_HTTP_STATUS
}

function test_liferay_batch_entrypoint_import_task_status {
	_test_liferay_batch_entrypoint_import_task_status "{\"executeStatus\": \"COMPLETED\", \"failedItems\": []}" "0"
	_test_liferay_batch_entrypoint_import_task_status "{\"executeStatus\": \"FAILED\"}" "1"
}

function test_liferay_batch_entrypoint_polls_with_backoff {
	set_up

	export _TEST_POLL_BODY="{\"executeStatus\": \"STARTED\"}"

	_TEST_ENTRYPOINT_OUTPUT=$(LIFERAY_BATCH_MAX_WAIT_SECONDS=3 _run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(wc --lines < "${_TEST_FIXTURE_DIR}/poll_count")" "3" \
		"$(_output_contains "did not reach a terminal state")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "1"

	tear_down
}

function test_liferay_batch_entrypoint_removes_the_items_file {
	set_up

	_TEST_ENTRYPOINT_OUTPUT=$(_run_entrypoint)

	local completed_file_count=$(ls "${_TEST_FIXTURE_DIR}/tmp" | wc --lines)

	export _TEST_POST_HTTP_STATUS="400"

	_TEST_ENTRYPOINT_OUTPUT=$(_run_entrypoint)

	assert_equals \
		"${completed_file_count}" "0" \
		"$(ls "${_TEST_FIXTURE_DIR}/tmp" | wc --lines)" "0"

	tear_down
}

function test_liferay_batch_entrypoint_reports_completed_with_failed_items {
	set_up

	export _TEST_POLL_BODY="{\"executeStatus\": \"COMPLETED\", \"failedItems\": [{\"itemIndex\": 3, \"message\": \"Unable to convert the item\"}]}"

	_TEST_ENTRYPOINT_OUTPUT=$(_run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(_output_contains "completed with 1 failed item(s)")" "true" \
		"$(_output_contains "Item 3: Unable to convert the item")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "1"

	tear_down
}

function test_liferay_batch_entrypoint_reports_poll_http_error {
	set_up

	export _TEST_POLL_BODY="{\"status\": \"NOT_FOUND\", \"title\": \"No ImportTask exists with the external reference code.\"}"
	export _TEST_POLL_HTTP_STATUS="404"

	_TEST_ENTRYPOINT_OUTPUT=$(LIFERAY_BATCH_MAX_WAIT_SECONDS=3 _run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(wc --lines < "${_TEST_FIXTURE_DIR}/poll_count")" "1" \
		"$(_output_contains "errored with HTTP status 404")" "true" \
		"$(_output_contains "No ImportTask exists with the external reference code.")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "1"

	tear_down
}

function test_liferay_batch_entrypoint_reports_post_error_body {
	set_up

	export _TEST_POST_BODY="{\"status\": \"BAD_REQUEST\", \"title\": \"This external reference code is already in use.\"}"
	export _TEST_POST_HTTP_STATUS="400"

	_TEST_ENTRYPOINT_OUTPUT=$(_run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(_output_contains "already in use")" "true" \
		"$(_output_contains "HTTP status 400")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "1"

	tear_down
}

function test_liferay_batch_entrypoint_reports_unparseable_poll_response {
	set_up

	export _TEST_POLL_BODY="<html><body>502 Bad Gateway</body></html>"

	_TEST_ENTRYPOINT_OUTPUT=$(_run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(wc --lines < "${_TEST_FIXTURE_DIR}/poll_count")" "1" \
		"$(_output_contains "Unable to read a status")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "1"

	tear_down
}

function test_liferay_batch_entrypoint_requires_oauth_app_erc {
	set_up

	_TEST_ENTRYPOINT_OUTPUT=$(LIFERAY_BATCH_OAUTH_APP_ERC="" _run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(_output_contains "Set the environment variable LIFERAY_BATCH_OAUTH_APP_ERC.")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "1"

	tear_down
}

function test_liferay_batch_entrypoint_retries_transient_poll_failure {
	set_up

	export _TEST_POLL_TRANSIENT_BODY="<html><body>503 Service Unavailable</body></html>"
	export _TEST_POLL_TRANSIENT_COUNT="2"

	_TEST_ENTRYPOINT_OUTPUT=$(_run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals \
		"$(wc --lines < "${_TEST_FIXTURE_DIR}/poll_count")" "3" \
		"$(_output_contains "errored with HTTP status 503")" "true" \
		"$(_output_contains "Retrying.")" "true" \
		"${_TEST_ENTRYPOINT_EXIT_CODE}" "0"

	tear_down
}

function _output_contains {
	if [[ "${_TEST_ENTRYPOINT_OUTPUT}" == *"${1}"* ]]
	then
		echo "true"

		return 0
	fi

	echo "false"

	return 1
}

function _run_entrypoint {
	PATH="${_TEST_FIXTURE_DIR}/bin:${PATH}" \
	TMPDIR="${_TEST_FIXTURE_DIR}/tmp" \
	LIFERAY_BATCH_DIR="${_TEST_FIXTURE_DIR}/batch" \
	LIFERAY_BATCH_OAUTH_APP_ERC="${LIFERAY_BATCH_OAUTH_APP_ERC-test}" \
	LIFERAY_BATCH_SITE_INITIALIZER_DIR="${_TEST_FIXTURE_DIR}/no-site-initializer" \
	LIFERAY_ROUTES_CLIENT_EXTENSION="${_TEST_FIXTURE_DIR}/lxc/ext-init-metadata" \
	LIFERAY_ROUTES_DXP="${_TEST_FIXTURE_DIR}/lxc/dxp-metadata" \
		bash ./templates/batch/resources/usr/local/bin/liferay_batch_entrypoint.sh 2>&1
}

function _test_liferay_batch_entrypoint_import_task_status {
	set_up

	export _TEST_POLL_BODY=${1}

	_TEST_ENTRYPOINT_OUTPUT=$(LIFERAY_BATCH_MAX_WAIT_SECONDS=3 _run_entrypoint)

	_TEST_ENTRYPOINT_EXIT_CODE=${?}

	assert_equals "${_TEST_ENTRYPOINT_EXIT_CODE}" "${2}"

	tear_down
}

function _write_curl_stub {
	cat > "${_TEST_FIXTURE_DIR}/bin/curl" <<-STUB_EOF
		#!/bin/bash

		url="\${@: -1}"

		if [[ "\${url}" == */o/oauth2/token ]]
		then
			echo "\${_TEST_TOKEN_BODY}"
			echo "\${_TEST_TOKEN_HTTP_STATUS}"
		elif [[ "\${url}" == */by-external-reference-code/* ]]
		then
			echo "poll" >> "\${_TEST_POLL_COUNT_FILE}"

			if [ "\$(wc --lines < "\${_TEST_POLL_COUNT_FILE}")" -le "\${_TEST_POLL_TRANSIENT_COUNT}" ]
			then
				echo "\${_TEST_POLL_TRANSIENT_BODY}"
				echo "503"

				exit 0
			fi

			echo "\${_TEST_POLL_BODY}"
			echo "\${_TEST_POLL_HTTP_STATUS}"
		else
			echo "\${_TEST_POST_BODY}"
			echo "\${_TEST_POST_HTTP_STATUS}"
		fi
	STUB_EOF

	chmod +x "${_TEST_FIXTURE_DIR}/bin/curl"
}

main
