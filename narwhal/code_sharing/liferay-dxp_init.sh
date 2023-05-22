#!/bin/bash

# shellcheck disable=SC2002,SC2013

set -e

BASE_DIR="${PWD}"
GITHUB_ADDRESS="git@github.com:tomposmiko"
REPO_NAME_DXP="liferay-dxp-new"
REPO_PATH_DXP="${BASE_DIR}/${REPO_NAME_DXP}"

function check_param {
	if [ -z "${1}" ]
	then
		echo "${2}"
		exit 1
	fi
}

function get_epoch_date {
	if [ -z "${EPOCH_START}" ]
	then
		EPOCH_START=$(date +%s)
	else
		EPOCH_FINISH=$(date +%s)
	fi
}

function init_repo {
	if [ -d "${REPO_PATH_DXP}" ]
	then
		echo "DXP repo already exists: '${REPO_PATH_DXP}'"
		exit 1
	fi

	echo -n "Initializing repo ..."

	git init -q "${REPO_PATH_DXP}"

	lcd "${REPO_PATH_DXP}"

	touch README.md
	git add .
	git commit -q -a -m "Initial commit"
	git remote add origin "${GITHUB_ADDRESS}/${REPO_NAME_DXP}"

	echo "done."
}

function lcd {
	check_param "${1}" "Missing directory name to enter"

	cd "${1}" || exit 3
}

function print_date {
	if [ -z "${EPOCH_FINISH}" ]
	then
		EPOCH_DATE="${EPOCH_START}"
	else
		EPOCH_DATE="${EPOCH_FINISH}"
	fi

	date "+%Y-%m-%d %H:%M:%S %Z" -d "@${EPOCH_DATE}" -u
}

function print_spent_time {
	time_diff_sec=$((EPOCH_FINISH - EPOCH_START))
	time_diff_human=$(date "+%H:%M:%S" -ud "@${time_diff_sec}")

	echo "Time spent: ${time_diff_human}."
}

get_epoch_date

echo "Start time: $(print_date)"

init_repo

get_epoch_date

echo "Finish time: $(print_date)"

print_spent_time
