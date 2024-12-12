#!/bin/bash

function main {
	if [ -e /usr/local/bin/liferay_node_runner_set_up.sh ]
	then
		/usr/local/bin/liferay_node_runner_set_up.sh
	fi

	${LIFERAY_NODE_RUNNER_START}

	if [ -e /usr/local/bin/liferay_node_runner_tear_down.sh ]
	then
		/usr/local/bin/liferay_node_runner_tear_down.sh
	fi
}

main