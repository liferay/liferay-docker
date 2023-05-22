#!/bin/bash

# shellcheck disable=2002,2013

set -e
set -o pipefail

BASE_DIR="${PWD}"

GITHUB_ADDRESS="git@github.com:tomposmiko"

REPO_NAME_DXP="liferay-dxp-new"
REPO_NAME_EE="liferay-portal-ee"

REPO_PATH_DXP="${BASE_DIR}/${REPO_NAME_DXP}"
REPO_PATH_EE="${BASE_DIR}/${REPO_NAME_EE}"

TAGS_FILE_DXP="/tmp/tags_file_dxp.txt"
TAGS_FILE_EE="/tmp/tags_file_ee.txt"
TAGS_FILE_NEW="/tmp/tags_file_new.txt"

VERSION="${1}"

function check_param {
	if [ -z "${1}" ]
	then
		echo "${2}"
		exit 1
	fi
}

function checkout_branch {
	local branch_name="${1}"

	check_param "${branch_name}" "Missing branch name"

	lcd "${REPO_PATH_DXP}"

	if (git show-ref --quiet "${branch_name}")
	then

		echo -n "Checking out branch '${branch_name}'..."
		git checkout -f -q "${branch_name}"
		echo "done."
	else
		echo -n "'No ${branch_name}' branch exists, creating..."
		git branch "${branch_name}"
		git checkout -f -q "${branch_name}"
		echo "done."
	fi
}

function fetch_repo {
	local repo_name="${1}"

	check_param "${repo_name}" "Missing repo name"

	lcd "${BASE_DIR}"

	if [ -d "${repo_name}" ]
	then
		echo -n "Repository '${repo_name}' exists, refreshing..."
		lcd "${repo_name}"
		git fetch --all
		echo "done."

	else
		echo -n "Repository '${repo_name}' does not exists, cloning..."
		git clone "${GITHUB_ADDRESS}/${repo_name}"
		echo "done."
	fi
}

function get_all_tags {
	git tag -l --sort=creatordate --format='%(refname:short)' "${VERSION}*"
}

function get_epoch_date {
	if [ -z "${EPOCH_START}" ]
	then
		EPOCH_START=$(date +%s)
	else
		EPOCH_FINISH=$(date +%s)
	fi

}

function get_new_tags {
	echo "Getting new tags... "

	lcd "${REPO_PATH_EE}"

	get_all_tags > "${TAGS_FILE_EE}"

	lcd "${REPO_PATH_DXP}"

	get_all_tags > "${TAGS_FILE_DXP}"

	local tag_name

	# shellcheck disable=SC2013
	for tag_name in $(cat "${TAGS_FILE_EE}")
	do
		if (! grep -qw "${tag_name}" "${TAGS_FILE_DXP}")
		then
			echo "${tag_name}"
		fi
	done

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
	time_diff_human=$(date "+%H:%M:%S" -d "@${time_diff_sec}" -u)

	echo "Time spent: ${time_diff_human}."
}

function pull_and_push_all_tags {
	get_new_tags > "${TAGS_FILE_NEW}"

	for version_minor in $(cat "${TAGS_FILE_NEW}" | cut -d "." -f2 | sort -nu)
	do
		local version_patch

		for version_patch in $(cat "${TAGS_FILE_NEW}" | grep "7.${version_minor}." | cut -d "." -f3 | cut -d "-" -f1 | sort -nu)
		do
			local version_semver
			version_semver="7.${version_minor}.${version_patch}"

			checkout_branch "${version_semver}"

			local version_full

			for version_full in $(cat "${TAGS_FILE_NEW}" | grep "${version_semver}")
			do
				pull_tag "${version_full}"
			done
		done
	done
}

function pull_tag {
	local tag_name="${1}"

	check_param "${tag_name}" "Missing tag name"

	echo
	echo "Pulling tag: ${tag_name} ..."

	if [ -z "${tag_name}" ]
	then
		echo "Missing tag"
		exit 1
	fi

	lcd "${REPO_PATH_EE}"

	echo -n ">>>> Checking out tag '${tag_name}'..."
	git checkout -q "${tag_name}"
	echo "done."

	lcd "${REPO_PATH_DXP}"

	echo -n ">>>> Running 'git gc'..."

	while (pgrep -f "git gc" >/dev/null)
	do
		sleep 1
	done

	git gc --quiet
	echo "done."

	rm -f .git/gc.log

	echo -n ">>>> Running 'git fsck'..."

	if (! git fsck --full >/dev/null 2>&1)
	then
		echo "The operation of 'git fsck' has failed."
		exit 1
	fi

	echo "done."

	echo -n ">>>> Running 'rsync'..."
	rsync -ar --delete --exclude '.git' "${REPO_PATH_EE}/" "${REPO_PATH_DXP}/"
	echo "done."

	echo -n ">>>> Running 'git add'..."
	git add .
	echo "done."

	echo -n ">>>> Running 'git commit'..."
	git commit -a -m "${tag_name}" -q
	echo "done."

	local commit_hash
	commit_hash=$(git rev-parse HEAD)

	echo -n ">>>> Running 'git tag'..."
	git tag "${tag_name}" "${commit_hash}"
	echo "done."

	echo "done."
}

function push_git_in_batches {
	local remote="${1}"
	local branch_name="${2}"
	local batch_size=100

	if git show-ref --quiet --verify "refs/remotes/${remote}/${branch_name}"
	then
		range="${remote}/${branch_name}..HEAD"
	else
		range="HEAD"
	fi

	packages=$(git log --first-parent --format=format:x "${range}" | wc -l)

	echo "Have to push ${packages} packages in range of ${range}"

	for batch_number in $(seq "${packages}" -"${batch_size}" 1)
	do
		batch_commit=$(git log --first-parent --format=format:%H -n1 --reverse --skip "${batch_number}")

		echo "Pushing ${batch_commit}..."

		git push -q "${remote}" "${batch_commit}:refs/heads/${branch_name}"
	done

	git push -q "${remote}" "HEAD:refs/heads/${branch_name}"
}

function push_repo {
	lcd "${REPO_PATH_DXP}"

	echo -n "Pushing all branches..."

	local branch_list
	branch_list=$(git for-each-ref --format='%(refname:short)' --sort=creatordate refs/heads/ | grep ^7)

	local branch_name

	for branch_name in ${branch_list}
	do
		checkout_branch "${branch_name}"

		push_git_in_batches origin "${branch_name}"
	done

	echo "done."

	echo -n "Pushing all tags..."
	git push -q --tags
	echo "done."
}

check_param "${VERSION}" "Missing version"

get_epoch_date

echo "Start date: $(print_date)"

fetch_repo "${REPO_NAME_DXP}"

fetch_repo "${REPO_NAME_EE}"

pull_and_push_all_tags

push_repo

get_epoch_date

echo "Finish date: $(print_date)"

print_spent_time
