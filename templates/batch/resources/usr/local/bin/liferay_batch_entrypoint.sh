#!/bin/bash

function check_http_code {
	local http_code="$1"

	if [ "$http_code" == "000" ]
	then
		echo "Error executing curl command. Please check arguments."
		return 1
	elif [ "$http_code" -ge 400 ]
	then
		if [ "$http_code" -eq 400 ]
		then
			echo "HTTP 400 Bad Request"
		elif [ "$http_code" -eq 401 ]
		then
			echo "HTTP 401 Unauthorized"
		elif [ "$http_code" -eq 403 ]
		then
			echo "HTTP 403 Forbidden"
		elif [ "$http_code" -eq 404 ]
		then
			echo "HTTP 404 Not Found"
		elif [ "$http_code" -eq 405 ]
		then
			echo "HTTP 405 Method Not Allowed"
		elif [ "$http_code" -eq 406 ]
		then
			echo "HTTP 406 Not Acceptable"
		elif [ "$http_code" -eq 407 ]
		then
			echo "HTTP 407 Proxy Authentication Required"
		elif [ "$http_code" -eq 408 ]
		then
			echo "HTTP 408 Request Timeout"
		elif [ "$http_code" -eq 409 ]
		then
			echo "HTTP 409 Conflict"
		elif [ "$http_code" -eq 410 ]
		then
			echo "HTTP 410 Gone"
		elif [ "$http_code" -eq 411 ]
		then
			echo "HTTP 411 Length Required"
		elif [ "$http_code" -eq 412 ]
		then
			echo "HTTP 412 Precondition Failed"
		elif [ "$http_code" -eq 413 ]
		then
			echo "HTTP 413 Payload Too Large"
		elif [ "$http_code" -eq 414 ]
		then
			echo "HTTP 414 URI Too Long"
		elif [ "$http_code" -eq 415 ]
		then
			echo "HTTP 415 Unsupported Media Type"
		elif [ "$http_code" -eq 416 ]
		then
			echo "HTTP 416 Range Not Satisfiable"
		elif [ "$http_code" -eq 417 ]
		then
			echo "HTTP 417 Expectation Failed"
		elif [ "$http_code" -eq 418 ]
		then
			echo "HTTP 418 I'm a teapot"
		elif [ "$http_code" -eq 421 ]
		then
			echo "HTTP 421 Misdirected Request"
		elif [ "$http_code" -eq 422 ]
		then
			echo "HTTP 422 Unprocessable Entity"
		elif [ "$http_code" -eq 423 ]
		then
			echo "HTTP 423 Locked"
		elif [ "$http_code" -eq 424 ]
		then
			echo "HTTP 424 Failed Dependency"
		elif [ "$http_code" -eq 425 ]
		then
			echo "HTTP 425 Too Early"
		elif [ "$http_code" -eq 426 ]
		then
			echo "HTTP 426 Upgrade Required"
		elif [ "$http_code" -eq 428 ]
		then
			echo "HTTP 428 Precondition Required"
		elif [ "$http_code" -eq 429 ]
		then
			echo "HTTP 429 Too Many Requests"
		elif [ "$http_code" -eq 431 ]
		then
			echo "HTTP 431 Request Header Fields Too Large"
		elif [ "$http_code" -eq 451 ]
		then
			echo "HTTP 451 Unavailable For Legal Reasons"
		elif [ "$http_code" -eq 500 ]
		then
			echo "HTTP 500 Internal Server Error"
		elif [ "$http_code" -eq 501 ]
		then
			echo "HTTP 501 Not Implemented"
		elif [ "$http_code" -eq 502 ]
		then
			echo "HTTP 502 Bad Gateway"
		elif [ "$http_code" -eq 503 ]
		then
			echo "HTTP 503 Service Unavailable"
		elif [ "$http_code" -eq 504 ]
		then
			echo "HTTP 504 Gateway Timeout"
		elif [ "$http_code" -eq 505 ]
		then
			echo "HTTP 505 HTTP Version Not Supported"
		elif [ "$http_code" -eq 506 ]
		then
			echo "HTTP 506 Variant Also Negotiates"
		elif [ "$http_code" -eq 507 ]
		then
			echo "HTTP 507 Insufficient Storage"
		elif [ "$http_code" -eq 508 ]
		then
			echo "HTTP 508 Loop Detected"
		elif [ "$http_code" -eq 510 ]
		then
			echo "HTTP 510 Not Extended"
		elif [ "$http_code" -eq 511 ]
		then
			echo "HTTP 511 Network Authentication Required"
		else
			echo "HTTP $http_code Error"
		fi
		return 1
	fi
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

	local lxc_dxp_main_domain=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.main.domain)

	if [ ! -n "${lxc_dxp_main_domain}" ]
	then
		lxc_dxp_main_domain=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.mainDomain)
	fi

	local lxc_dxp_server_protocol=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.server.protocol)
	local oauth2_client_id=$(cat ${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.id)
	local oauth2_client_secret=$(cat ${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.secret)
	local oauth2_token_uri=$(cat ${LIFERAY_ROUTES_CLIENT_EXTENSION}/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.token.uri)

	echo "LXC DXP Main Domain: ${lxc_dxp_main_domain}"
	echo "LXC DXP Server Protocol: ${lxc_dxp_server_protocol}"
	echo ""
	echo "OAuth Client ID: ${oauth2_client_id}"
	echo "OAuth Client Secret: ${oauth2_client_secret}"
	echo "OAuth Token URI: ${oauth2_token_uri}"
	echo ""

	local http_code_output=$(mktemp)

	local oauth2_token_response=$(\
		curl \
			-H "Content-type: application/x-www-form-urlencoded" \
			-X POST \
			-d "client_id=${oauth2_client_id}&client_secret=${oauth2_client_secret}&grant_type=client_credentials" \
			-s \
			-w "%output{$http_code_output}%{http_code}" \
			${LIFERAY_BATCH_CURL_OPTIONS} \
			"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${oauth2_token_uri}")

	local http_code="$(cat $http_code_output)"

	if ! check_http_code "$http_code"
	then
		echo "Unable to get OAuth 2 token response: ${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${oauth2_token_uri}"
		exit 1
	fi

	echo "OAuth Token Response: ${oauth2_token_response}"
	echo ""

	local oauth2_access_token=$(jq --raw-output ".access_token" <<< ${oauth2_token_response})

	if [ "${oauth2_access_token}" == "" ]
	then
		echo "Unable to get OAuth 2 access token."

		exit 1
	fi

	if [ -e "/opt/liferay/site-initializer/site-initializer.json" ]
	then
		echo "Processing: /opt/liferay/site-initializer/site-initializer.json"
		echo ""

		local href="/o/headless-site/v1.0/sites/by-external-reference-code/"

		echo "HREF: ${href}"

		local site=$(jq --raw-output '.' /opt/liferay/site-initializer/site-initializer.json)

		echo "Site: ${site}"

		local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${site}")

		local http_code_output=$(mktemp)

		local put_response=$(\
			curl \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${oauth2_access_token}" \
				-H "Content-Type: multipart/form-data" \
				-X PUT \
				-F "file=@/opt/liferay/site-initializer/site-initializer.zip;type=application/zip" \
				-F "site=${site}" \
				-s \
				-w "%output{$http_code_output}%{http_code}" \
				${LIFERAY_BATCH_CURL_OPTIONS} \
				"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${external_reference_code}")

		local http_code="$(cat $http_code_output)"

		if ! check_http_code "$http_code"
		then
			echo "Unable to PUT resource: ${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${external_reference_code}"
			exit 1
		fi

		echo "PUT Response: ${put_response}"
		echo ""

		if [ ! -n "${put_response}" ]
		then
			echo "Received empty PUT response. Please check Liferay logs for more information."

			exit 1
		fi
	fi

	find /opt/liferay/batch -type f -name "*.batch-engine-data.json" -print0 2> /dev/null | LC_ALL=C sort --zero-terminated |
	while IFS= read -r -d "" file_name
	do
		echo "Processing: ${file_name}"
		echo ""

		local href=$(jq --raw-output ".actions.createBatch.href" ${file_name})

		if [[ "$href" == "null" ]]
		then
			local class_name=$(jq --raw-output ".configuration.className" ${file_name})

			if [[ "$class_name" == "null" ]]
			then
				echo "Batch data file is missing configuration class name."

				exit 1
			fi

			href="/o/headless-batch-engine/v1.0/import-task/${class_name}"
		fi

		href="${href#*://*/}"

		if [[ ! $href =~ ^/.* ]]
		then
			href="/${href}"
		fi

		echo "HREF: ${href}"

		jq --raw-output ".items" ${file_name} > /tmp/liferay_batch_entrypoint.items.json

		echo "Items: $(</tmp/liferay_batch_entrypoint.items.json)"

		local parameters=$(jq --raw-output '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' ${file_name} 2>/dev/null)

		if [ "${parameters}" != "" ]
		then
			parameters="?${parameters}"
		fi

		echo "Parameters: ${parameters}"

		local http_code_output=$(mktemp)

		local post_response=$(\
			curl \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${oauth2_access_token}" \
				-H "Content-Type: application/json" \
				-X POST \
				-d @/tmp/liferay_batch_entrypoint.items.json \
				-s \
				-w "%output{$http_code_output}%{http_code}" \
				${LIFERAY_BATCH_CURL_OPTIONS} \
				"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${parameters}")

		local http_code="$(cat $http_code_output)"

		if ! check_http_code "$http_code"
		then
			echo "Unable to POST resource: ${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}"
			exit 1
		fi

		echo "POST Response: ${post_response}"
		echo ""

		if [ ! -n "${post_response}" ]
		then
			echo "Received empty POST response. Please check Liferay logs for more information."

			rm /tmp/liferay_batch_entrypoint.items.json

			exit 1
		fi

		local external_reference_code=$(jq --raw-output ".externalReferenceCode" <<< "${post_response}")

		local status=$(jq --raw-output ".executeStatus//.status" <<< "${post_response}")

		until [ "${status}" == "COMPLETED" ] || [ "${status}" == "FAILED" ] || [ "${status}" == "NOT_FOUND" ]
		do
			local http_code_output=$(mktemp)

			local status_response=$(\
				curl \
					-H "accept: application/json" \
					-H "Authorization: Bearer ${oauth2_access_token}" \
					-X 'GET' \
					-s \
					-w "%output{$http_code_output}%{http_code}" \
					${LIFERAY_BATCH_CURL_OPTIONS} \
					"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code}")

			local http_code="$(cat $http_code_output)"

			if ! check_http_code "$http_code"
			then
				echo "Unable to get status for import task with external reference code ${external_reference_code}: ${status_response}"
				exit 1
			fi

			status=$(jq --raw-output '.executeStatus//.status' <<< "${status_response}")

			echo "Execute Status: ${status}"
		done

		rm /tmp/liferay_batch_entrypoint.items.json

		if [ "${status}" == "FAILED" ]
		then
			echo "Batch import task process failed. Please check Liferay logs for more information."
			exit 1
		fi
	done
}

main