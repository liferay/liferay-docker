################################################################################
## Supported Environment Variables
################################################################################
#
# BATCH_CURL_FLAGS      (optional) set flags on all curl commands
# BATCH_DIRECTORY       (optional) the top directory in which to locate batch
#                       data files (default to "/batch")
# BATCH_FILE_EXTENSION  (optional) the extension of batch data files to process
#                       (default to "*.jsont")
# BATCH_OAUTH_APP_ERC   (required) specify by external reference code the oauth
#                       application to use
# BATCH_VERBOSE         (optional) sets the verbose output (any value will be
#                       considered true). When true also sets curl -v flag
#

BATCH_DIRECTORY=${BATCH_DIRECTORY:-/batch}
BATCH_FILE_EXTENSION=${BATCH_FILE_EXTENSION:-*.jsont}

if [ -e /etc/liferay/localdev/rootCA.pem ]
then
	BATCH_CURL_FLAGS="${BATCH_CURL_FLAGS} --cacert /etc/liferay/localdev/rootCA.pem"
fi

if [ ! -z ${BATCH_VERBOSE:+x} ]
then
	BATCH_CURL_FLAGS="${BATCH_CURL_FLAGS} -v"
fi

function main {
	local DATA_FILES=$(find $BATCH_DIRECTORY -type f -name "$BATCH_FILE_EXTENSION")

	if [ "${DATA_FILES}" == "" ]
	then
		echo "There are no data files. Exiting with nothing to do!"
		exit 1
	fi

	if [ "$BATCH_OAUTH_APP_ERC" == "" ]
	then
		cat <<EOF
No OAuth Profile was selected for JOB processing!

Please set the environment variable BATCH_OAUTH_APP_ERC in your
LCP.json file.

e.g.

"env": {
	"BATCH_OAUTH_APP_ERC": "foo-oauth-application-headless-server"
},

EOF
		exit 1
	fi

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "BATCH_OAUTH_APP_ERC = ${BATCH_OAUTH_APP_ERC}"
	fi

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "########################"
		echo "Mounted Config:"
		find /etc/liferay/lxc/ext-init-metadata -type l -not -ipath "*/..data" -print -exec sed 's/^/    /' {} \; -exec echo "" \;
		find /etc/liferay/lxc/dxp-metadata -type l -not -ipath "*/..data" -print -exec sed 's/^/    /' {} \; -exec echo "" \;
	fi

	DXP_MAIN_DOMAIN=$(cat /etc/liferay/lxc/dxp-metadata/com.liferay.lxc.dxp.mainDomain)
	DXP_SERVER_PROTOCOL=$(cat /etc/liferay/lxc/dxp-metadata/com.liferay.lxc.dxp.server.protocol)
	OAUTH2_CLIENT_ID=$(cat /etc/liferay/lxc/ext-init-metadata/${BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.id)
	OAUTH2_CLIENT_SECRET=$(cat /etc/liferay/lxc/ext-init-metadata/${BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.secret)
	OAUTH2_TOKEN_URI=$(cat /etc/liferay/lxc/ext-init-metadata/${BATCH_OAUTH_APP_ERC}.oauth2.token.uri)

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "########################"
		echo "DXP_MAIN_DOMAIN: ${DXP_MAIN_DOMAIN}"
		echo "DXP_SERVER_PROTOCOL: ${DXP_SERVER_PROTOCOL}"
		echo "BATCH_OAUTH_APP_ERC: ${BATCH_OAUTH_APP_ERC}"
		echo "OAUTH2_CLIENT_ID: ${OAUTH2_CLIENT_ID}"
		echo "OAUTH2_CLIENT_SECRET: ${OAUTH2_CLIENT_SECRET}"
		echo "OAUTH2_TOKEN_URI: ${OAUTH2_TOKEN_URI}"
		echo "########################"
	fi

	local TOKEN_RESULT=$(\
		curl \
			-s \
			$BATCH_CURL_FLAGS \
			-X POST \
			"${DXP_SERVER_PROTOCOL}://${DXP_MAIN_DOMAIN}${OAUTH2_TOKEN_URI}" \
			-H 'Content-type: application/x-www-form-urlencoded' \
			-d "grant_type=client_credentials&client_id=${OAUTH2_CLIENT_ID}&client_secret=${OAUTH2_CLIENT_SECRET}" \
		| jq -r '.')

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "TOKEN_RESULT: ${TOKEN_RESULT}"
	fi

	ACCESS_TOKEN=$(jq -r '.access_token' <<< $TOKEN_RESULT)

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "ACCESS_TOKEN: ${ACCESS_TOKEN}"
	fi

	if [ "${ACCESS_TOKEN}" == "null" ]
	then
		echo "Failed to obtain ACCESS_TOKEN!"
		exit 1
	fi

	for i in $DATA_FILES
	do
		process_batch $i
	done
}

process_batch() {
	echo "########################"
	echo "######### BATCH ${1}"

	local BATCH_ITEMS=$(jq -r '.items' ${1})

	local BATCH_HREF=$(jq -r '.actions.createBatch.href' ${1})
	BATCH_HREF="${BATCH_HREF#*://*/}"

	if [[ ! $BATCH_HREF =~ ^/.* ]]
	then
		BATCH_HREF="/${BATCH_HREF}"
	fi

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "BATCH_HREF=${BATCH_HREF}"
	fi

	local PARAMETERS=$(jq -r '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' ${1} 2>/dev/null)

	if [ "$PARAMETERS" != "" ]
	then
		PARAMETERS="?${PARAMETERS}"
	fi

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "PARAMETERS=${PARAMETERS}"
	fi

	local RESULT=$(\
		curl \
			-s \
			$BATCH_CURL_FLAGS \
			-X 'POST' \
			"${DXP_SERVER_PROTOCOL}://${DXP_MAIN_DOMAIN}${BATCH_HREF}${PARAMETERS}" \
			-H 'accept: application/json' \
			-H 'Content-Type: application/json' \
			-H "Authorization: Bearer ${ACCESS_TOKEN}" \
			-d "${BATCH_ITEMS}" \
		| jq -r '.')

	if [ "${RESULT}x" == "x" ]
	then
		echo "An error occured!"
		exit 1
	fi

	if [ ! -z ${BATCH_VERBOSE:+x} ]
	then
		echo "RESULT=${RESULT}"
	fi

	local BATCH_EXTERNAL_REFERENCE_CODE=$(jq -r '.externalReferenceCode' <<< "$RESULT")

	local BATCH_STATUS=$(jq -r '.executeStatus//.status' <<< "$RESULT")

	until [ "${BATCH_STATUS}" == "COMPLETED" ] || [ "${BATCH_STATUS}" == "FAILED" ] || [ "${BATCH_STATUS}" == "NOT_FOUND" ]
	do
		local RESULT=$(\
			curl \
				-s \
				$BATCH_CURL_FLAGS \
				-X 'GET' \
				"${DXP_SERVER_PROTOCOL}://${DXP_MAIN_DOMAIN}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${BATCH_EXTERNAL_REFERENCE_CODE}" \
				-H 'accept: application/json' \
				-H "Authorization: Bearer ${ACCESS_TOKEN}" \
			| jq -r '.')

		BATCH_STATUS=$(jq -r '.executeStatus//.status' <<< "$RESULT")

		echo "BATCH STATUS: ${BATCH_STATUS}"
	done

	if [ "${BATCH_STATUS}" == "FAILED" ]
	then
		exit 1
	fi
}

main