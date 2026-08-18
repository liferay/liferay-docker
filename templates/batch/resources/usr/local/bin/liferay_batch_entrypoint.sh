#!/bin/bash

function execute_curl {
	local response

	response=$(curl --silent --write-out "\n%{http_code}" "${@}")

	if [ "${?}" -gt 0 ]
	then
		LIFERAY_BATCH_HTTP_BODY="Unable to complete the request."
		LIFERAY_BATCH_HTTP_STATUS="000"

		return 1
	fi

	LIFERAY_BATCH_HTTP_BODY="${response%$'\n'*}"
	LIFERAY_BATCH_HTTP_STATUS="${response##*$'\n'}"

	if [ "${LIFERAY_BATCH_HTTP_STATUS}" == "000" ] ||
	   [ "${LIFERAY_BATCH_HTTP_STATUS}" -ge 400 ]
	then
		return 1
	fi

	return 0
}

function main {
	if [ ! -n "${LIFERAY_BATCH_OAUTH_APP_ERC}" ]
	then
		echo "Set the environment variable LIFERAY_BATCH_OAUTH_APP_ERC."

		exit 1
	fi

	if [ ! -n "${LIFERAY_BATCH_CURL_OPTIONS}" ]
	then
		LIFERAY_BATCH_CURL_OPTIONS=" "
	fi

	if [ ! -n "${LIFERAY_ROUTES_CLIENT_EXTENSION}" ]
	then
		LIFERAY_ROUTES_CLIENT_EXTENSION="/etc/liferay/lxc/ext-init-metadata"
	fi

	if [ ! -n "${LIFERAY_ROUTES_DXP}" ]
	then
		LIFERAY_ROUTES_DXP="/etc/liferay/lxc/dxp-metadata"
	fi

	echo "OAuth Application ERC: ${LIFERAY_BATCH_OAUTH_APP_ERC}"
	echo ""

	local lxc_dxp_main_domain=$(cat "${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.main.domain")

	if [ ! -n "${lxc_dxp_main_domain}" ]
	then
		lxc_dxp_main_domain=$(cat "${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.mainDomain")
	fi

	LIFERAY_BATCH_DXP_URL="$(cat "${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.server.protocol")://${lxc_dxp_main_domain}"
	LIFERAY_BATCH_OAUTH2_CLIENT_ID=$(cat "${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.id")
	LIFERAY_BATCH_OAUTH2_CLIENT_SECRET=$(cat "${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.secret")
	LIFERAY_BATCH_OAUTH2_TOKEN_URI=$(cat "${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.token.uri")

	echo "DXP URL: ${LIFERAY_BATCH_DXP_URL}"
	echo ""

	if ! request_oauth2_access_token
	then
		exit 1
	fi

	if ! process_site_initializer
	then
		exit 1
	fi

	find /opt/liferay/batch -type f -name "*.batch-engine-data.json" -print0 2> /dev/null | LC_ALL=C sort --zero-terminated |
	while IFS= read -r -d "" file_name
	do
		if ! process_batch_data_file "${file_name}"
		then
			exit 1
		fi
	done
}

function process_batch_data_file {
	local file_name="${1}"

	echo "Processing: ${file_name}"
	echo ""

	local href=$(jq --raw-output ".actions.createBatch.href" "${file_name}")

	if [ "${href}" == "null" ]
	then
		local class_name=$(jq --raw-output ".configuration.className" "${file_name}")

		if [ "${class_name}" == "null" ]
		then
			echo "Batch data file is missing configuration class name."

			return 1
		fi

		href="/o/headless-batch-engine/v1.0/import-task/${class_name}"
	fi

	href="${href#*://*/}"

	if [[ ! ${href} =~ ^/.* ]]
	then
		href="/${href}"
	fi

	echo "HREF: ${href}"

	jq --raw-output ".items" "${file_name}" > /tmp/liferay_batch_entrypoint.items.json

	echo "Items: $(</tmp/liferay_batch_entrypoint.items.json)"

	local parameters=$(jq --raw-output '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' "${file_name}" 2> /dev/null)

	if [ "${parameters}" != "" ]
	then
		parameters="?${parameters}"
	fi

	echo "Parameters: ${parameters}"

	if ! execute_curl \
			--data @/tmp/liferay_batch_entrypoint.items.json \
			--header "Accept: application/json" \
			--header "Authorization: Bearer ${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" \
			--header "Content-Type: application/json" \
			--request POST \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${LIFERAY_BATCH_DXP_URL}${href}${parameters}"
	then
		echo "POST ${LIFERAY_BATCH_DXP_URL}${href}${parameters} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}."

		return 1
	fi

	echo "POST Response: ${LIFERAY_BATCH_HTTP_BODY}"
	echo ""

	if [ ! -n "${LIFERAY_BATCH_HTTP_BODY}" ]
	then
		echo "Received empty POST response. Check Liferay logs for more information."

		rm /tmp/liferay_batch_entrypoint.items.json

		return 1
	fi

	local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${LIFERAY_BATCH_HTTP_BODY}")

	local status=$(jq --raw-output ".executeStatus//.status" <<< "${LIFERAY_BATCH_HTTP_BODY}")

	wait_for_import_task "${external_reference_code}" "${status}"
}

function process_site_initializer {
	if [ ! -e "/opt/liferay/site-initializer/site-initializer.json" ]
	then
		return 0
	fi

	echo "Processing: /opt/liferay/site-initializer/site-initializer.json"
	echo ""

	local href="/o/headless-site/v1.0/sites/by-external-reference-code/"

	echo "HREF: ${href}"

	local site=$(jq --raw-output '.' /opt/liferay/site-initializer/site-initializer.json)

	echo "Site: ${site}"

	local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${site}")

	if ! execute_curl \
			--form "file=@/opt/liferay/site-initializer/site-initializer.zip;type=application/zip" \
			--form "site=${site}" \
			--header "Accept: application/json" \
			--header "Authorization: Bearer ${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" \
			--header "Content-Type: multipart/form-data" \
			--request PUT \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${LIFERAY_BATCH_DXP_URL}${href}${external_reference_code}"
	then
		echo "PUT ${LIFERAY_BATCH_DXP_URL}${href}${external_reference_code} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}."

		return 1
	fi

	echo "PUT Response: ${LIFERAY_BATCH_HTTP_BODY}"
	echo ""

	if [ ! -n "${LIFERAY_BATCH_HTTP_BODY}" ]
	then
		echo "Received empty PUT response. Check Liferay logs for more information."

		return 1
	fi

	return 0
}

function request_oauth2_access_token {
	if ! execute_curl \
			--data "client_id=${LIFERAY_BATCH_OAUTH2_CLIENT_ID}&client_secret=${LIFERAY_BATCH_OAUTH2_CLIENT_SECRET}&grant_type=client_credentials" \
			--header "Content-type: application/x-www-form-urlencoded" \
			--request POST \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${LIFERAY_BATCH_DXP_URL}${LIFERAY_BATCH_OAUTH2_TOKEN_URI}"
	then
		echo "POST ${LIFERAY_BATCH_DXP_URL}${LIFERAY_BATCH_OAUTH2_TOKEN_URI} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}."

		return 1
	fi

	LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN=$(jq --raw-output ".access_token" <<< "${LIFERAY_BATCH_HTTP_BODY}")

	if [ "${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" == "" ]
	then
		echo "Unable to get OAuth 2 access token."

		return 1
	fi

	return 0
}

function wait_for_import_task {
	local external_reference_code="${1}"
	local status="${2}"

	until [ "${status}" == "COMPLETED" ] || [ "${status}" == "FAILED" ] || [ "${status}" == "NOT_FOUND" ]
	do
		if ! execute_curl \
				--header "Accept: application/json" \
				--header "Authorization: Bearer ${LIFERAY_BATCH_OAUTH2_ACCESS_TOKEN}" \
				--request GET \
				${LIFERAY_BATCH_CURL_OPTIONS} \
				"${LIFERAY_BATCH_DXP_URL}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code}"
		then
			echo "GET ${LIFERAY_BATCH_DXP_URL}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code} errored with HTTP status ${LIFERAY_BATCH_HTTP_STATUS}."

			return 1
		fi

		status=$(jq --raw-output '.executeStatus//.status' <<< "${LIFERAY_BATCH_HTTP_BODY}")

		echo "Execute Status: ${status}"
	done

	rm /tmp/liferay_batch_entrypoint.items.json

	if [ "${status}" == "FAILED" ]
	then
		echo "Batch import task failed. Check Liferay logs for more information."

		return 1
	fi

	return 0
}

main
