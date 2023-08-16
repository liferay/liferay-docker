#!/bin/bash

# shellcheck disable=2002,2013

set -o pipefail

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_liferay_common.sh"

export BASE_DIR="${PWD}"

export GIT_AUTHOR_EMAIL="er-hu@liferay.com"
export GIT_AUTHOR_NAME="Enterprise Release"
export GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"
export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}"

export REPO_PATH_DXP="${BASE_DIR}/liferay-dxp"
export REPO_PATH_EE="${BASE_DIR}/liferay-portal-ee"

function checkout_tag {
	local repository="${1}"
	local tag_name="${2}"

	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_cd "${BASE_DIR}/${repository}"

	git reset --hard -q
	git clean -fdqX

	git checkout -f -q "${tag_name}"
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

function fetch_repository {
	if [ "${RUN_FETCH_REPOSITORY}" != "true" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${BASE_DIR}/${1}"

	git fetch --all --tags
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

function prepare_repositories {
	lc_time_run clone_repository liferay-dxp

	lc_time_run clone_repository liferay-portal-ee

	lc_time_run fetch_repository liferay-dxp

	lc_time_run fetch_repository liferay-portal-ee
}

function push_to_origin {
	if [ "${RUN_PUSH_TO_ORIGIN}" != "true" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${REPO_PATH_DXP}"

	git push -q origin "${1}"
}

function run_rsync {
	rsync -ar --inplace --delete --exclude '.git' --times "${REPO_PATH_EE}/" "${REPO_PATH_DXP}/"
}
