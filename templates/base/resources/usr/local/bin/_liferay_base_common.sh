#!/bin/bash

function forward_signals_and_wait {
	local pid=${1}

	trap 'kill "${pid}"' INT TERM

	#
	# The first wait returns as soon as the trap runs, while the process is
	# still shutting down. The second wait blocks until it actually exits.
	#

	wait "${pid}"

	wait "${pid}"
}