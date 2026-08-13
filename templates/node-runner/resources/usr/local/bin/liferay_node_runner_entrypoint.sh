#!/bin/bash

function main {
	source /usr/local/bin/set_node_version.sh

	if [ -e /usr/local/bin/liferay_node_runner_set_up.sh ]
	then
		/usr/local/bin/liferay_node_runner_set_up.sh
	fi

	if [ -n "${1}" ]
	then
		"${@}"
	else
		${LIFERAY_NODE_RUNNER_START}
	fi

	if [ -e /usr/local/bin/liferay_node_runner_tear_down.sh ]
	then
		/usr/local/bin/liferay_node_runner_tear_down.sh
	fi
}

main "${@}"