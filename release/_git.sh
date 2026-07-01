#!/bin/bash

source ../_release_common.sh

function clean_portal_repository {
	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}"

	if [ -e "${_BUILD_DIR}/built.sha" ] &&
	   [ "$(cat "${_BUILD_DIR}/built.sha")" == "${LIFERAY_RELEASE_GIT_REF}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git reset --hard && git clean -dfx
}

function clone_repository {
	if [ -e "${_PROJECTS_DIR}/${1}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir --parents "${_PROJECTS_DIR}"

	lc_cd "${_PROJECTS_DIR}"

	if [ -e "/home/me/dev/projects/${1}" ]
	then
		echo "Copying Git repository from /home/me/dev/projects/${1}."

		cp --archive "/home/me/dev/projects/${1}" "${_PROJECTS_DIR}"
	elif [ -e "/opt/dev/projects/github/${1}" ]
	then
		echo "Copying Git repository from /opt/dev/projects/github/${1}."

		cp --archive "/opt/dev/projects/github/${1}" "${_PROJECTS_DIR}"
	else
		git clone git@github.com:liferay/"${1}".git
	fi

	lc_cd "${1}"

	if (git remote get-url upstream &>/dev/null)
	then
		git remote set-url upstream git@github.com:liferay/"${1}".git
	else
		git remote add upstream git@github.com:liferay/"${1}".git
	fi

	if (! git remote get-url brianchandotcom &>/dev/null)
	then
		git remote add brianchandotcom git@github.com:brianchandotcom/"${1}".git
	fi

	git remote --verbose
}

function commit_changes {
	local file

	while IFS= read -r file
	do
		git add "${file}"
	done <<< "${1}"

	git commit --message "${2}"
}

function generate_release_notes {
	if is_ai_hub_release
	then
		lc_log INFO "Release notes should not be generated for AI Hub releases."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local ga_version=7.4.13-ga1

	if ! is_quarterly_release
	then
		ga_version=${_PRODUCT_VERSION%%-u*}-ga1
	fi

	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}"

	git log "tags/${ga_version}..HEAD" --pretty="%s %H" | \
		sed --expression "/c394bcbc1c36af47e66678c470d623568d3f1e88/c\LPD-27038/" | \
		sed --expression "/8a80898965553c441eef73d6d6839d0b5712ca43/c\LPD-27038/" | \
		grep --extended-regexp "^[A-Z][A-Z0-9]*-[0-9]+" | \
		sed --expression "s/^\([A-Z][A-Z0-9]*-[0-9]*\).*/\\1/" | \
		sort | \
		uniq | \
		grep --invert-match LRCI | \
		grep --invert-match LRQA | \
		grep --invert-match POSHI | \
		grep --invert-match RELEASE | \
		paste --delimiters=',' --serial > "${_BUILD_DIR}/release/release-notes.txt"
}

function prepare_branch_to_commit {
	lc_cd "${1}"

	git restore .

	git checkout master

	local base_branch="master"

	if [ -n "${3}" ]
	then
		base_branch=${3}
	fi

	local repository_name=${2}

	_TEMP_BRANCH="temp-branch-$(date "+%Y%m%d%H%M%S")"

	git fetch --no-tags "git@github.com:liferay/${repository_name}.git" "${base_branch}:${_TEMP_BRANCH}"

	git checkout "${_TEMP_BRANCH}"

	if [ "$(git rev-parse --abbrev-ref HEAD)" != "${_TEMP_BRANCH}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function push_branch_to_liferay_release_fork {
	local branch_name=${1}
	local repository_name=${2}

	if ! git remote get-url liferay-release &> /dev/null
	then
		git remote add liferay-release "git@github.com:liferay-release/${repository_name}.git"
	fi

	git push --force "liferay-release" "${branch_name}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to push branch ${branch_name} to liferay-release/${repository_name}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function set_git_sha {
	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}"

	_GIT_SHA=$(git rev-parse HEAD)
	_GIT_SHA_SHORT=$(git rev-parse --short HEAD)
}

function update_portal_repository {
	trap 'return "${LIFERAY_COMMON_EXIT_CODE_BAD}"' ERR

	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}"

	local checkout_ref=${LIFERAY_RELEASE_GIT_REF}

	if [ -e "${_BUILD_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}.sha" ] &&
	   [ "$(cat "${_BUILD_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}.sha")" == "${LIFERAY_RELEASE_GIT_REF}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already checked out in ${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if (echo "${LIFERAY_RELEASE_GIT_REF}" | grep --extended-regexp --quiet "^[[:alnum:]\.-]+/[0-9a-z]{40}$")
	then
		checkout_ref="${LIFERAY_RELEASE_GIT_REF#*/}"

		LIFERAY_RELEASE_GIT_REF="${LIFERAY_RELEASE_GIT_REF%/*}"
	elif (echo "${LIFERAY_RELEASE_GIT_REF}" | grep --extended-regexp --quiet "^[0-9a-f]{40}$")
	then
		lc_log INFO "Looking for a tag that matches Git SHA ${LIFERAY_RELEASE_GIT_REF}."

		LIFERAY_RELEASE_GIT_REF=$(git ls-remote upstream | grep "${LIFERAY_RELEASE_GIT_REF}" | grep refs/tags/fix-pack-fix- | head --lines=1 | sed --expression "s#.*/##")

		if [ -n "${LIFERAY_RELEASE_GIT_REF}" ]
		then
			lc_log INFO "Found tag ${LIFERAY_RELEASE_GIT_REF}."
		else
			lc_log ERROR "No tag found."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi

	if (! git remote get-url "${LIFERAY_PORTAL_REPOSITORY_OWNER}" &>/dev/null)
	then
		git remote add "${LIFERAY_PORTAL_REPOSITORY_OWNER}" "git@github.com:${LIFERAY_PORTAL_REPOSITORY_OWNER}/${LIFERAY_PORTAL_REPOSITORY_NAME}.git"
	fi

	if ! is_ai_hub_release && [ -n "$(git ls-remote upstream refs/tags/"${LIFERAY_RELEASE_GIT_REF}")" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_REF} tag exists on remote."

		git fetch --force upstream tag "${LIFERAY_RELEASE_GIT_REF}"
	elif ! is_ai_hub_release && [ -n "$(git ls-remote upstream refs/heads/"${LIFERAY_RELEASE_GIT_REF}")" ]
	then
		echo "${LIFERAY_RELEASE_GIT_REF} branch exists on remote."

		git fetch --force --update-head-ok upstream "${LIFERAY_RELEASE_GIT_REF}:${LIFERAY_RELEASE_GIT_REF}"
	elif [ -n "$(git ls-remote "${LIFERAY_PORTAL_REPOSITORY_OWNER}" refs/heads/"${LIFERAY_RELEASE_GIT_REF}")" ]
	then
		echo "${LIFERAY_RELEASE_GIT_REF} branch exists on ${LIFERAY_PORTAL_REPOSITORY_OWNER}'s remote."

		git fetch --force --update-head-ok "${LIFERAY_PORTAL_REPOSITORY_OWNER}" "${LIFERAY_RELEASE_GIT_REF}:${LIFERAY_RELEASE_GIT_REF}"
	else
		lc_log ERROR "${LIFERAY_RELEASE_GIT_REF} does not exist."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	git reset --hard && git clean -dfx

	git checkout "${checkout_ref}"

	git status

	echo "${LIFERAY_RELEASE_GIT_REF}" > "${_BUILD_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}.sha"
}

function update_release_tool_repository {
	trap 'return "${LIFERAY_COMMON_EXIT_CODE_BAD}"' ERR

	lc_cd "${_PROJECTS_DIR}/liferay-release-tool-ee"

	git reset --hard && git clean -dfx

	local release_tool_sha=$(lc_get_property "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/release.properties" "release.tool.sha")

	if [ ! -n "${release_tool_sha}" ]
	then
		lc_log ERROR "The property \"release.tool.sha\" is missing from ${LIFERAY_PORTAL_REPOSITORY_NAME}/release.properties."

		return 1
	fi

	if [ -e "${_BUILD_DIR}/liferay-release-tool-ee.sha" ] &&
	   [ "$(cat "${_BUILD_DIR}/liferay-release-tool-ee.sha")" == "${release_tool_sha}" ]
	then
		lc_log INFO "${release_tool_sha} was already checked out in ${_PROJECTS_DIR}/liferay-release-tool-ee."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git fetch --force --prune upstream

	git fetch --force --prune --tags upstream

	git checkout master

	git reset --hard FETCH_HEAD

	git checkout "${release_tool_sha}"

	echo "${release_tool_sha}" > "${_BUILD_DIR}/liferay-release-tool-ee.sha"
}