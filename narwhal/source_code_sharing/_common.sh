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

	git add -f .

	git commit -a -m "${tag_name}" -q

	git tag "${tag_name}"
}

function clone_repository {
	local repository_name="${1}"
	local repository_path="${2}"

	if [ -z "${repository_path}" ]
	then
		repository_path="${repository_name}"
	fi

	if [ -e "${repository_path}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -e "/home/me/dev/projects/${repository_name}" ]
	then
		echo "Copying Git repository from /home/me/dev/projects/${repository_name}."

		cp -a "/home/me/dev/projects/${repository_name}" "${repository_path}"
	elif [ -e "/opt/dev/projects/github/${repository_name}" ]
	then
		echo "Copying Git repository from /opt/dev/projects/github/${repository_path}."

		cp -a "/opt/dev/projects/github/${repository_name}" "${repository_path}"
	else
		git clone "git@github.com:liferay/${repository_name}.git" "${repository_path}"
	fi

	lc_cd "${repository_path}"

	if (git remote get-url upstream &>/dev/null)
	then
		git remote set-url upstream "git@github.com:liferay/${repository_name}.git"
	else
		git remote add upstream "git@github.com:liferay/${repository_name}.git"
	fi

	git remote --verbose
}

function fetch_repository {
	if [ "${RUN_FETCH_REPOSITORY}" != "true" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${BASE_DIR}/${1}"

	git fetch --all --force --tags
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
