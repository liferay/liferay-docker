#!/bin/bash

function clean_portal_repository {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	_GIT_SHA=$(git rev-parse HEAD)
	_GIT_SHA_SHORT=$(git rev-parse --short HEAD)

	if [ -e "${_BUILD_DIR}"/built.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built.sha) == "${LIFERAY_RELEASE_GIT_SHA}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_SHA} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git reset --hard && git clean -dfx
}

function clone_repository {
	if [ -e "${_PROJECTS_DIR}/${1}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir -p "${_PROJECTS_DIR}"

	lc_cd "${_PROJECTS_DIR}"

	if [ -e "/home/me/dev/projects/${1}" ]
	then
		echo "Copying Git repository from /home/me/dev/projects/${1}."

		cp -a "/home/me/dev/projects/${1}" "${_PROJECTS_DIR}"
	elif [ -e "/opt/dev/projects/github/${1}" ]
	then
		echo "Copying Git repository from /opt/dev/projects/github/${1}."

		cp -a "/opt/dev/projects/github/${1}" "${_PROJECTS_DIR}"
	else
		git clone git@github.com:liferay/"${1}".git
	fi

	cd "${1}"

	if (git remote get-url upstream &>/dev/null)
	then
		git remote set-url upstream git@github.com:liferay/"${1}".git
	else
		git remote add upstream git@github.com:liferay/"${1}".git
	fi

	git remote --verbose
}

function update_portal_repository {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	if [ -e "${_BUILD_DIR}"/liferay-portal-ee.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/liferay-portal-ee.sha) == "${LIFERAY_RELEASE_GIT_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_SHA} was already checked out in ${_PROJECTS_DIR}/liferay-portal-ee."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if (echo "${LIFERAY_RELEASE_GIT_SHA}" | grep -qE "[0-9a-f]{40}")
	then
		LIFERAY_RELEASE_GIT_SHA=$(git ls-remote upstream | grep "${LIFERAY_RELEASE_GIT_SHA}" | grep refs/tags/fix-pack-fix- | head -n 1 | sed -e "s#.*/##")
	fi

	if [ -n "$(git ls-remote upstream refs/tags/"${LIFERAY_RELEASE_GIT_SHA}")" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_SHA} tag exists on remote."

		git fetch --force upstream tag "${LIFERAY_RELEASE_GIT_SHA}"
	elif [ -n "$(git ls-remote upstream refs/heads/"${LIFERAY_RELEASE_GIT_SHA}")" ]
	then
		echo "${LIFERAY_RELEASE_GIT_SHA} branch exists on remote."

		git fetch --force --update-head-ok upstream "${LIFERAY_RELEASE_GIT_SHA}:${LIFERAY_RELEASE_GIT_SHA}"
	else
		lc_log ERROR "${LIFERAY_RELEASE_GIT_SHA} does not exist." 

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	git reset --hard && git clean -dfx

	git checkout "${LIFERAY_RELEASE_GIT_SHA}"

	git status

	echo "${LIFERAY_RELEASE_GIT_SHA}" > "${_BUILD_DIR}"/liferay-portal-ee.sha
}

function update_release_tool_repository {
	lc_cd "${_PROJECTS_DIR}"/liferay-release-tool-ee

	git reset --hard && git clean -dfx

	local release_tool_sha=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.tool.sha")

	if [ ! -n "${release_tool_sha}" ]
	then
		lc_log ERROR "The property \"release.tool.sha\" is missing from liferay-portal-ee/release.properties."

		return 1
	fi

	if [ -e "${_BUILD_DIR}"/liferay-release-tool-ee.sha ] &&
	   [ $(cat "${_BUILD_DIR}"/liferay-release-tool-ee.sha) == "${release_tool_sha}" ]
	then
		lc_log INFO "${release_tool_sha} was already checked out in ${_PROJECTS_DIR}/liferay-release-tool-ee."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git fetch --force --prune --tags upstream || return 1

	git checkout "${release_tool_sha}" || return 1

	echo "${release_tool_sha}" > "${_BUILD_DIR}"/liferay-release-tool-ee.sha
}