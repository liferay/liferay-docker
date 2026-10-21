#!/bin/bash

source /usr/local/bin/_liferay_base_common.sh

function main {
	source /usr/local/bin/set_node_version.sh

	if [ -e /usr/local/bin/liferay_node_runner_set_up.sh ]
	then
		/usr/local/bin/liferay_node_runner_set_up.sh
	fi

	${LIFERAY_NODE_RUNNER_START} &

	forward_signals_and_wait "${!}"

	if [ -e /usr/local/bin/liferay_node_runner_tear_down.sh ]
	then
		/usr/local/bin/liferay_node_runner_tear_down.sh
	fi
}

main