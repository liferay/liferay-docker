#!/bin/bash

function main {
	local available_node_versions=$( \
		ls /usr/local/node | \
		paste --delimiters=',' --serial | \
		sed --expression "s/,/, /g")

	if [ -z "${NODE_VERSION}" ]
	then
		echo "[LIFERAY] The \"NODE_VERSION\" environment variable is not set."
		echo "[LIFERAY] Set it to one of the available Node versions: ${available_node_versions}."

		exit 1
	fi

	if [ -e "/usr/local/node/${NODE_VERSION}" ]
	then
		export PATH="/usr/local/node/${NODE_VERSION}/bin:${PATH}"

		echo "[LIFERAY] Using Node ${NODE_VERSION}. You can use another version by setting the \"NODE_VERSION\" environment variable."
		echo "[LIFERAY] Available Node versions: ${available_node_versions}."
	else
		echo "[LIFERAY] Node \"${NODE_VERSION}\" is not available in this Docker image."
		echo "[LIFERAY] Available Node versions: ${available_node_versions}."

		exit 1
	fi
}

main