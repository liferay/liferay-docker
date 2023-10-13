#!/bin/bash

function main {
	if [ ! -n "${LIFERAY_BATCH_OAUTH_APP_ERC}" ]
	then
		echo "Set the environment variable LIFERAY_BATCH_OAUTH_APP_ERC."

		exit 1
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

	local curl_options="${LIFERAY_BATCH_CURL_OPTIONS}"

	if [ -e /opt/liferay/caroot/rootCA.pem ]
	then
		curl_options="${curl_options} --cacert /opt/liferay/caroot/rootCA.pem"
	fi

	local oauth2_token_response=$(\
		curl \
			-H "Content-type: application/x-www-form-urlencoded" \
			-X POST \
			-d "client_id=${oauth2_client_id}&client_secret=${oauth2_client_secret}&grant_type=client_credentials" \
			-s \
			${curl_options} \
			"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${oauth2_token_uri}" \
		| jq -r ".")

	echo "OAuth Token Response: ${oauth2_token_response}"
	echo ""

	local oauth2_access_token=$(jq -r ".access_token" <<< ${oauth2_token_response})

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

		local site=$(jq -r '.' /opt/liferay/site-initializer/site-initializer.json)

		echo "Site: ${site}"

		local external_reference_code=$(jq -r ".externalReferenceCode" <<< "${site}")

		local put_response=$(\
			curl \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${oauth2_access_token}" \
				-H "Content-Type: multipart/form-data" \
				-X PUT \
				-F "file=@/opt/liferay/site-initializer/site-initializer.zip;type=application/zip" \
				-F "site=${site}" \
				-s \
				${curl_options} \
				"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${external_reference_code}" \
			| jq -r ".")

		echo "PUT Response: ${put_response}"
		echo ""

		if [ ! -n "${put_response}" ]
		then
			echo "Received invalid PUT response."

			exit 1
		fi
	fi

	find /opt/liferay/batch -type f -name "*.batch-engine-data.json" -print0 2> /dev/null |
	while IFS= read -r -d "" file_name
	do
		echo "Processing: ${file_name}"
		echo ""

		local href=$(jq -r ".actions.createBatch.href" ${file_name})

		href="${href#*://*/}"

		if [[ ! $href =~ ^/.* ]]
		then
			href="/${href}"
		fi

		echo "HREF: ${href}"

		local items=$(jq -r ".items" ${file_name})

		echo "Items: ${items}"

		local parameters=$(jq -r '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' ${file_name} 2>/dev/null)

		if [ "${parameters}" != "" ]
		then
			parameters="?${parameters}"
		fi

		echo "Parameters: ${parameters}"

		local post_response=$(\
			curl \
				-H "Accept: application/json" \
				-H "Authorization: Bearer ${oauth2_access_token}" \
				-H "Content-Type: application/json" \
				-X POST \
				-d "${items}" \
				-s \
				${curl_options} \
				"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}${href}${parameters}" \
			| jq -r ".")

		echo "POST Response: ${post_response}"
		echo ""

		if [ ! -n "${post_response}" ]
		then
			echo "Received invalid POST response."

			exit 1
		fi

		local external_reference_code=$(jq -r ".externalReferenceCode" <<< "${post_response}")

		local status=$(jq -r ".executeStatus//.status" <<< "${post_response}")

		until [ "${status}" == "COMPLETED" ] || [ "${status}" == "FAILED" ] || [ "${status}" == "NOT_FOUND" ]
		do
			local status_response=$(\
				curl \
					-s \
					${curl_options} \
					-X 'GET' \
					"${lxc_dxp_server_protocol}://${lxc_dxp_main_domain}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code}" \
					-H 'accept: application/json' \
					-H "Authorization: Bearer ${oauth2_access_token}" \
				| jq -r '.')

			status=$(jq -r '.executeStatus//.status' <<< "${status_response}")

			echo "Execute Status: ${status}"
		done

		if [ "${status}" == "FAILED" ]
		then
			exit 1
		fi
	done
}

main