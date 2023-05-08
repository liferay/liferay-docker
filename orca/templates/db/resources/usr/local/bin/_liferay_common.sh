#!/bin/bash

function block_begin {
	lecho ">>> BEGIN: ${1}"
}

function block_finish {
	lecho ">>> FINISH: ${1}"

	echo
}

function fail {
	lecho >&2 "!!! ERROR: ${1}"

	exit 1
}

function msg {
	lecho "--- ${1}"
}

function lecho {
	local ts=$(date "+%Y-%m-%d %T.%6N")

	echo "${ts} [orca] ${1}"
}
