#!/bin/bash

# shellcheck disable=2002,2013

set -o pipefail

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_liferay_common.sh"

BASE_DIR="${PWD}"

REPO_PATH_DXP="${BASE_DIR}/liferay-dxp"
REPO_PATH_EE="${BASE_DIR}/liferay-portal-ee"

function checkout_branch {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	local branch_name="${2}"

	lc_cd "${BASE_DIR}/${1}"

	git reset --hard
	git clean -fdX

	if (git show-ref --quiet "${branch_name}")
	then
		git checkout -f -q "${branch_name}"
		git pull origin "${branch_name}"
	else
		git branch "${branch_name}"
		git checkout -f -q "${branch_name}"
	fi
}

function checkout_tag_simple {
	lc_cd "${BASE_DIR}/${1}"

	git checkout "${2}"
}

function commit_and_tag {
	local tag_name="${1}"

	git add .

	git commit -a -m "${tag_name}" -q

	git tag "${tag_name}"
}

function clone_repository {
	if [ -d "${1}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git clone "git@github.com:liferay/${1}"
}

function download_to_cache {
	# FIXME: lc_download should be devided to this one and a copy function

	local file_url=${1}

	if [ -z "${file_url}" ]
	then
		lc_log ERROR "File URL is not set."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local file_name=${2}

	if [ -z "${file_name}" ]
	then
		file_name=${file_url##*/}
	fi

	local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

	if [ -e "${cache_file}" ]
	then
		lc_log DEBUG "Skipping the download of ${file_url} because it already exists."

		return
	fi

	local dir_cache_file
	dir_cache_file=$(dirname "${cache_file}")

	mkdir -p "${dir_cache_file}"

	lc_log DEBUG "Downloading ${file_url}."

	local current_date
	current_date=$(lc_date)

	local timestamp
	timestamp=$(lc_date "${current_date}" "+%Y%m%d%H%M%S")

	if (! curl "${file_url}" --fail --output "${cache_file}.temp${timestamp}" --silent)
	then
		lc_log ERROR "Unable to download ${file_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	else
		mv "${cache_file}.temp${timestamp}" "${cache_file}"
	fi
}

function fetch_repository {
	if [ "${RUN_FETCH_REPOSITORY}" != "yes" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${BASE_DIR}/${1}"

	git fetch --all
}

function run_git_maintenance {
	while (pgrep -f "git gc" >/dev/null)
	do
		sleep 1
	done

	rm -f .git/gc.log

	git gc --quiet

	if (! git fsck --full >/dev/null 2>&1)
	then
		echo "Running of 'git fsck' has failed."

		exit 1
	fi
}

function copy_tag {
	local tag_name="${1}"

	lc_time_run checkout_tag liferay-portal-ee "${tag_name}"

	lc_cd "${REPO_PATH_DXP}"

	lc_time_run run_git_maintenance

	lc_time_run run_rsync "${tag_name}"

	lc_time_run commit_and_tag "${tag_name}"
}


function push_to_origin {
	if [ "${RUN_PUSH_TO_ORIGIN}" != "yes" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${REPO_PATH_DXP}"

	git push -q origin "${1}"
}

function run_rsync {
	rsync -ar --delete --exclude '.git' "${REPO_PATH_EE}/" "${REPO_PATH_DXP}/"
}
