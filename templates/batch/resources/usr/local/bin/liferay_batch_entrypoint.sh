################################################################################
## Supported Environment Variables
################################################################################
#
# LIFERAY_BATCH_CURL_FLAGS      (optional) set flags on all curl commands
# LIFERAY_BATCH_DIRECTORY       (optional) the top directory in which to locate
#                               batch data files (default to "/batch")
# LIFERAY_BATCH_FILE_EXTENSION  (optional) the extension of batch data files to
#                               process (default to "*.batch-engine-data.json")
# LIFERAY_BATCH_OAUTH_APP_ERC   (required) specify by external reference code
#                               the oauth application to use
# LIFERAY_BATCH_VERBOSE         (optional) sets the verbose output (any value
#                               will be considered true). When true also sets
#                               curl -v flag
#

LIFERAY_BATCH_DIRECTORY=${LIFERAY_BATCH_DIRECTORY:-/batch}
LIFERAY_BATCH_FILE_EXTENSION=${LIFERAY_BATCH_FILE_EXTENSION:-*.batch-engine-data.json}

if [ -e /etc/liferay/localdev/rootCA.pem ]
then
	LIFERAY_BATCH_CURL_FLAGS="${LIFERAY_BATCH_CURL_FLAGS} --cacert /etc/liferay/localdev/rootCA.pem"
fi

if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
then
	LIFERAY_BATCH_CURL_FLAGS="${LIFERAY_BATCH_CURL_FLAGS} -v"
fi

function main {
	local data_files=$(find ${LIFERAY_BATCH_DIRECTORY} -type f -name "${LIFERAY_BATCH_FILE_EXTENSION}")

	if [ "${data_files}" == "" ]
	then
		echo "There are no data files. Exiting with nothing to do!"
		exit 1
	fi

	if [ "${LIFERAY_BATCH_OAUTH_APP_ERC}" == "" ]
	then
		cat <<EOF
No OAuth Profile was selected for JOB processing!

Please set the environment variable LIFERAY_BATCH_OAUTH_APP_ERC in your
LCP.json file.

e.g.

"env": {
	"LIFERAY_BATCH_OAUTH_APP_ERC": "foo-oauth-application-headless-server"
},

EOF
		exit 1
	fi

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "LIFERAY_BATCH_OAUTH_APP_ERC=${LIFERAY_BATCH_OAUTH_APP_ERC}"
	fi

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "########################"
		echo "Mounted Config:"
		find /etc/liferay/lxc/ext-init-metadata -type l -not -ipath "*/..data" -print -exec sed 's/^/    /' {} \; -exec echo "" \;
		find /etc/liferay/lxc/dxp-metadata -type l -not -ipath "*/..data" -print -exec sed 's/^/    /' {} \; -exec echo "" \;
	fi

	LIFERAY_BATCH_DXP_MAIN_DOMAIN=$(cat /etc/liferay/lxc/dxp-metadata/com.liferay.lxc.dxp.mainDomain)
	LIFERAY_BATCH_DXP_SERVER_PROTOCOL=$(cat /etc/liferay/lxc/dxp-metadata/com.liferay.lxc.dxp.server.protocol)
	LIFERAY_BATCH_OAUTH2_CLIENT_ID=$(cat /etc/liferay/lxc/ext-init-metadata/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.id)
	LIFERAY_BATCH_OAUTH2_CLIENT_SECRET=$(cat /etc/liferay/lxc/ext-init-metadata/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.headless.server.client.secret)
	LIFERAY_BATCH_OAUTH2_TOKEN_URI=$(cat /etc/liferay/lxc/ext-init-metadata/${LIFERAY_BATCH_OAUTH_APP_ERC}.oauth2.token.uri)

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "########################"
		echo "LIFERAY_BATCH_DXP_MAIN_DOMAIN=${LIFERAY_BATCH_DXP_MAIN_DOMAIN}"
		echo "LIFERAY_BATCH_DXP_SERVER_PROTOCOL=${LIFERAY_BATCH_DXP_SERVER_PROTOCOL}"
		echo "LIFERAY_BATCH_OAUTH_APP_ERC=${LIFERAY_BATCH_OAUTH_APP_ERC}"
		echo "LIFERAY_BATCH_OAUTH2_CLIENT_ID=${LIFERAY_BATCH_OAUTH2_CLIENT_ID}"
		echo "LIFERAY_BATCH_OAUTH2_CLIENT_SECRET=${LIFERAY_BATCH_OAUTH2_CLIENT_SECRET}"
		echo "LIFERAY_BATCH_OAUTH2_TOKEN_URI=${LIFERAY_BATCH_OAUTH2_TOKEN_URI}"
		echo "########################"
	fi

	local token_result=$(\
		curl \
			-s \
			${LIFERAY_BATCH_CURL_FLAGS} \
			-X POST \
			"${LIFERAY_BATCH_DXP_SERVER_PROTOCOL}://${LIFERAY_BATCH_DXP_MAIN_DOMAIN}${LIFERAY_BATCH_OAUTH2_TOKEN_URI}" \
			-H 'Content-type: application/x-www-form-urlencoded' \
			-d "grant_type=client_credentials&client_id=${LIFERAY_BATCH_OAUTH2_CLIENT_ID}&client_secret=${LIFERAY_BATCH_OAUTH2_CLIENT_SECRET}" \
		| jq -r '.')

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "token_result=${token_result}"
	fi

	LIFERAY_BATCH_ACCESS_TOKEN=$(jq -r '.access_token' <<< ${token_result})

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "LIFERAY_BATCH_ACCESS_TOKEN=${LIFERAY_BATCH_ACCESS_TOKEN}"
	fi

	if [ "${LIFERAY_BATCH_ACCESS_TOKEN}" == "null" ]
	then
		echo "Failed to obtain LIFERAY_BATCH_ACCESS_TOKEN!"
		exit 1
	fi

	for i in ${data_files}
	do
		process_batch $i
	done
}

process_batch() {
	echo "########################"
	echo "######### BATCH ${1}"

	local items=$(jq -r '.items' ${1})

	local href=$(jq -r '.actions.createBatch.href' ${1})
	href="${href#*://*/}"

	if [[ ! $href =~ ^/.* ]]
	then
		href="/${href}"
	fi

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "href=${href}"
	fi

	local parameters=$(jq -r '.configuration.parameters | [map_values(. | @uri) | to_entries[] | .key + "=" + .value] | join("&")' ${1} 2>/dev/null)

	if [ "${parameters}" != "" ]
	then
		parameters="?${parameters}"
	fi

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "parameters=${parameters}"
	fi

	local post_result=$(\
		curl \
			-s \
			${LIFERAY_BATCH_CURL_FLAGS} \
			-X 'POST' \
			"${LIFERAY_BATCH_DXP_SERVER_PROTOCOL}://${LIFERAY_BATCH_DXP_MAIN_DOMAIN}${href}${parameters}" \
			-H 'accept: application/json' \
			-H 'Content-Type: application/json' \
			-H "Authorization: Bearer ${LIFERAY_BATCH_ACCESS_TOKEN}" \
			-d "${items}" \
		| jq -r '.')

	if [ "${post_result}x" == "x" ]
	then
		echo "An error occured!"
		exit 1
	fi

	if [ ! -z ${LIFERAY_BATCH_VERBOSE:+x} ]
	then
		echo "post_result=${post_result}"
	fi

	local external_reference_code=$(jq -r '.externalReferenceCode' <<< "${post_result}")

	local execute_status=$(jq -r '.executeStatus//.status' <<< "${post_result}")

	until [ "${execute_status}" == "COMPLETED" ] || [ "${execute_status}" == "FAILED" ] || [ "${execute_status}" == "NOT_FOUND" ]
	do
		local status_result=$(\
			curl \
				-s \
				${LIFERAY_BATCH_CURL_FLAGS} \
				-X 'GET' \
				"${LIFERAY_BATCH_DXP_SERVER_PROTOCOL}://${LIFERAY_BATCH_DXP_MAIN_DOMAIN}/o/headless-batch-engine/v1.0/import-task/by-external-reference-code/${external_reference_code}" \
				-H 'accept: application/json' \
				-H "Authorization: Bearer ${LIFERAY_BATCH_ACCESS_TOKEN}" \
			| jq -r '.')

		execute_status=$(jq -r '.executeStatus//.status' <<< "$status_result")

		echo "execute_status=${execute_status}"
	done

	if [ "${execute_status}" == "FAILED" ]
	then
		exit 1
	fi
}

main