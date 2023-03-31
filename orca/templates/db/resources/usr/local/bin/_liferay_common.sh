#!/bin/bash

function block_begin {
	text="${1}"

	lecho ">>> BEGIN: ${text}"
}

function block_finish {
	text="${1}"

	lecho ">>> FINISH: ${text}"

	echo
}

function fail {
	text="${1}"

	local ts=$(date "+%Y-%m-%d %T.%6N")

	lecho >&2 "!!! ERROR: ${text}"

	echo

	exit 1
}

function msg {
	text="${1}"

	lecho "--- MSG: ${text}"
}

function lecho {
	text="${1}"

	local ts=$(date "+%Y-%m-%d %T.%6N")

	echo "${ts} [orca][$0] ${text}"
}
