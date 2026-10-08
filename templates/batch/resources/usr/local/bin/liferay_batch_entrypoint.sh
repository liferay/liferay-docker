#!/bin/bash

function execute_curl {
	local response

	response=$(curl --silent --write-out "\n%{http_code}" "${@}")

	if [[ "${?}" -gt 0 ]]
	then
		LIFERAY_BATCH_HTTP_BODY="Unable to complete the request."
		LIFERAY_BATCH_HTTP_STATUS="000"

		return 1
	fi

	LIFERAY_BATCH_HTTP_BODY=${response%$'\n'*}
	LIFERAY_BATCH_HTTP_STATUS=${response##*$'\n'}

	if [ "${LIFERAY_BATCH_HTTP_STATUS}" == "000" ] ||
	   [[ "${LIFERAY_BATCH_HTTP_STATUS}" -ge 400 ]]
	then
		return 1
	fi

	return 0
}

function is_transient_http_status {
	if [ "${LIFERAY_BATCH_HTTP_STATUS}" == "000" ] ||
	   [[ "${LIFERAY_BATCH_HTTP_STATUS}" -ge 500 ]]
	then
		return 0
	fi

	return 1
}

function log {
	echo "${1}"
}

function main {
	if [ ! -n "${LIFERAY_BATCH_OAUTH_APP_ERC}" ]
	then
		log "Set the environment variable LIFERAY_BATCH_OAUTH_APP_ERC." ERROR

		exit 1
	fi

	if [ ! -n "${LIFERAY_BATCH_CURL_OPTIONS}" ]
	then
		LIFERAY_BATCH_CURL_OPTIONS=" "
	fi

	if [ ! -n "${LIFERAY_BATCH_DIR}" ]
	then
		LIFERAY_BATCH_DIR="/opt/liferay/batch"
	fi

	if [ ! -n "${LIFERAY_BATCH_MAX_WAIT_SECONDS}" ]
	then
		LIFERAY_BATCH_MAX_WAIT_SECONDS=540
	fi

	if [ ! -n "${LIFERAY_BATCH_SITE_INITIALIZER_DIR}" ]
	then
		LIFERAY_BATCH_SITE_INITIALIZER_DIR="/opt/liferay/site-initializer"
	fi

	if [ ! -n "${LIFERAY_ROUTES_CLIENT_EXTENSION}" ]
	then
		LIFERAY_ROUTES_CLIENT_EXTENSION="/etc/liferay/lxc/ext-init-metadata"
	fi

	if [ ! -n "${LIFERAY_ROUTES_DXP}" ]
	then
		LIFERAY_ROUTES_DXP="/etc/liferay/lxc/dxp-metadata"
	fi

	log "OAuth Application ERC: ${LIFERAY_BATCH_OAUTH_APP_ERC}"

	local lxc_dxp_main_domain=$(cat "${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.main.domain")

	if [ ! -n "${lxc_dxp_main_domain}" ]
	then
		lxc_dxp_main_domain=$(cat "${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.mainDomain")
	fi

	LIFERAY_BATCH_DXP_URL="$(cat "${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.server.protocol")://${lxc_dxp_main_domain}"
	LIFERAY_BATCH_OAUTH2_CLIENT_ID=$(cat "${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.id")
	LIFERAY_BATCH_OAUTH2_CLIENT_SECRET=$(cat "${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.secret")
	LIFERAY_BATCH_OAUTH2_TOKEN_URI=$(cat "${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.token.uri")

	log "DXP URL: ${LIFERAY_BATCH_DXP_URL}"

	if ! request_oauth2_access_token
	then
		exit 1
	fi

	if ! process_site_initializer
	then
		exit 1
	fi

	local file_name

	find "${LIFERAY_BATCH_DIR}" \
		-type f \
		-name "*.batch-engine-data.json" \
		-print0 2> /dev/null | \
		LC_ALL=C sort --zero-terminated | \
		while IFS= read -r -d "" file_name
		do
			if ! process_batch_data_file "${file_name}"
			then
				exit 1
			fi
		done
}

function process_batch_data_file {
	local items_file=$(mktemp)

	_process_batch_data_file "${1}" "${items_file}"

	local exit_code=${?}

	rm --force "${items_file}"

	return "${exit_code}"
}

function process_site_initializer {
	if [ ! -e "${LIFERAY_BATCH_SITE_INITIALIZER_DIR}/site-initializer.json" ]
	then
		return 0
	fi

	log "Processing: ${LIFERAY_BATCH_SITE_INITIALIZER_DIR}/site-initializer.json"

	local href="/o/headless-site/v1.0/sites/by-external-reference-code/"

	log "HREF: ${href}"

	local site=$(jq --raw-output '.' "${LIFERAY_BATCH_SITE_INITIALIZER_DIR}/site-initializer.json")

	log "Site: ${site}"

	local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${site}")

	if ! execute_curl \
			--form "file=@${LIFERAY_BATCH_SITE_INITIALIZER_DIR}/site-initializer.zip;type=application/zip" \
			--form "site=${site}" \
			--header "Accept: application/json" \
			--header "Authorization: Bearer ${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" \
			--header "Content-Type: multipart/form-data" \
			--request PUT \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${LIFERAY_BATCH_DXP_URL}${href}${external_reference_code}"
	then
		log "PUT ${LIFERAY_BATCH_DXP_URL}${href}${external_reference_code} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}. ${LIFERAY_BATCH_HTTP_BODY}" ERROR

		return 1
	fi

	log "PUT Response: ${LIFERAY_BATCH_HTTP_BODY}"

	if [ ! -n "${LIFERAY_BATCH_HTTP_BODY}" ]
	then
		log "Received empty PUT response. Check Liferay logs for more information." ERROR

		return 1
	fi

	return 0
}

function refresh_oauth2_access_token {
	if [[ "$((SECONDS - LIFERAY_BATCH_OAUTH2_TOKEN_SECONDS))" -lt 480 ]]
	then
		return 0
	fi

	request_oauth2_access_token
}

function request_oauth2_access_token {
	if ! execute_curl \
			--data "client_id=${LIFERAY_BATCH_OAUTH2_CLIENT_ID}&client_secret=${LIFERAY_BATCH_OAUTH2_CLIENT_SECRET}&grant_type=client_credentials" \
			--header "Content-type: application/x-www-form-urlencoded" \
			--request POST \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${LIFERAY_BATCH_DXP_URL}${LIFERAY_BATCH_OAUTH2_TOKEN_URI}"
	then
		log "POST ${LIFERAY_BATCH_DXP_URL}${LIFERAY_BATCH_OAUTH2_TOKEN_URI} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}. ${LIFERAY_BATCH_HTTP_BODY}" ERROR

		return 1
	fi

	LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN=$(jq --raw-output ".access_token" <<< "${LIFERAY_BATCH_HTTP_BODY}")

	if [ "${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" == "" ]
	then
		log "Unable to get OAuth 2 access token." ERROR

		return 1
	fi

	LIFERAY_BATCH_OAUTH2_TOKEN_SECONDS=${SECONDS}

	return 0
}

function wait_for_import_task {
	local external_reference_code=${1}

	local import_task_url="${LIFERAY_BATCH_DXP_URL}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code}"

	local sleep_seconds=1
	local status="UNKNOWN"
	local waited_seconds=0

	while true
	do
		if ! refresh_oauth2_access_token
		then
			return 1
		fi

		if execute_curl \
				--header "Accept: application/json" \
				--header "Authorization: Bearer ${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" \
				--request GET \
				${LIFERAY_BATCH_CURL_OPTIONS} \
				"${import_task_url}"
		then
			if ! status=$( \
				jq \
					--exit-status \
					--raw-output \
					'.executeStatus' <<< "${LIFERAY_BATCH_HTTP_BODY}")
			then
				log "Unable to read a status for batch import task ${external_reference_code}. ${LIFERAY_BATCH_HTTP_BODY}" ERROR

				return 1
			fi

			log "Execute Status: ${status}"

			if [ "${status}" == "COMPLETED" ]
			then
				local failed_items=$(jq --raw-output '.failedItems//[] | length' <<< "${LIFERAY_BATCH_HTTP_BODY}")

				if [ "${failed_items}" != "0" ]
				then
					local failed_item_messages=$(jq --raw-output '[(.failedItems//[])[] | "Item \(.itemIndex): \(.message)"] | join(" ")' <<< "${LIFERAY_BATCH_HTTP_BODY}")

					log "Batch import task ${external_reference_code} completed with ${failed_items} failed item(s). ${failed_item_messages}" ERROR

					return 1
				fi

				return 0
			fi

			if [ "${status}" == "FAILED" ]
			then
				log "Batch import task ${external_reference_code} reported ${status}. ${LIFERAY_BATCH_HTTP_BODY}" ERROR

				return 1
			fi
		elif is_transient_http_status
		then
			log "GET ${import_task_url} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}. ${LIFERAY_BATCH_HTTP_BODY} Retrying." WARNING
		else
			log "GET ${import_task_url} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}. ${LIFERAY_BATCH_HTTP_BODY}" ERROR

			return 1
		fi

		if [[ "${waited_seconds}" -ge "${LIFERAY_BATCH_MAX_WAIT_SECONDS}" ]]
		then
			log "Batch import task ${external_reference_code} did not reach a terminal state within ${waited_seconds} seconds. The last reported status was ${status}." ERROR

			return 1
		fi

		sleep "${sleep_seconds}"

		waited_seconds=$((waited_seconds + sleep_seconds))

		if [[ "${sleep_seconds}" -lt 16 ]]
		then
			sleep_seconds=$((sleep_seconds * 2))
		fi
	done
}

function _process_batch_data_file {
	local file_name=${1}
	local items_file=${2}

	log "Processing: ${file_name}"

	local href=$(jq --raw-output ".actions.createBatch.href" "${file_name}")

	if [ "${href}" == "null" ]
	then
		local class_name=$(jq --raw-output ".configuration.className" "${file_name}")

		if [ "${class_name}" == "null" ]
		then
			log "Batch data file is missing configuration class name." ERROR

			return 1
		fi

		href="/o/headless-batch-engine/v1.0/import-task/${class_name}"
	fi

	href=$(echo "${href}" | sed --expression "s|^[^/]*://[^/]*/||")

	if [[ ! "${href}" =~ ^/.* ]]
	then
		href="/${href}"
	fi

	log "HREF: ${href}"

	jq --raw-output ".items" "${file_name}" > "${items_file}"

	log "Items: $(< "${items_file}")"

	local parameters=$(jq --raw-output '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' "${file_name}" 2> /dev/null)

	if [ "${parameters}" != "" ]
	then
		parameters="?${parameters}"
	fi

	log "Parameters: ${parameters}"

	if ! refresh_oauth2_access_token
	then
		return 1
	fi

	if ! execute_curl \
			--data "@${items_file}" \
			--header "Accept: application/json" \
			--header "Authorization: Bearer ${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" \
			--header "Content-Type: application/json" \
			--request POST \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${LIFERAY_BATCH_DXP_URL}${href}${parameters}"
	then
		log "POST ${LIFERAY_BATCH_DXP_URL}${href}${parameters} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}. ${LIFERAY_BATCH_HTTP_BODY}" ERROR

		return 1
	fi

	log "POST Response: ${LIFERAY_BATCH_HTTP_BODY}"

	if [ ! -n "${LIFERAY_BATCH_HTTP_BODY}" ]
	then
		log "Received empty POST response. Check Liferay logs for more information." ERROR

		return 1
	fi

	local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${LIFERAY_BATCH_HTTP_BODY}")

	wait_for_import_task "${external_reference_code}"
}

main
