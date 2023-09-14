#!/bin/bash

function clean_portal_git {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	GIT_SHA=$(git rev-parse HEAD)
	GIT_SHA_SHORT=$(git rev-parse --short HEAD)

	if [ -e "${_BUILD_DIR}"/built-sha ] &&
	   [ $(cat "${_BUILD_DIR}"/built-sha) == "${LIFERAY_RELEASE_GIT_SHA}${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_SHA} was already built in ${_BUILD_DIR}."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git reset --hard

	git clean -dfx
}

function clone_repository {
	if [ -e "${_PROJECTS_DIR}/${1}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir -p "${_PROJECTS_DIR}"

	lc_cd "${_PROJECTS_DIR}"

	git clone git@github.com:liferay/"${1}".git
}

function update_portal_git {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	if [ -e "${_BUILD_DIR}"/sha-liferay-portal-ee ] &&
	   [ $(cat "${_BUILD_DIR}"/sha-liferay-portal-ee) == "${LIFERAY_RELEASE_GIT_SHA}" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_SHA} was already checked out."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ -n "$(git ls-remote origin refs/tags/"${LIFERAY_RELEASE_GIT_SHA}")" ]
	then
		lc_log INFO "${LIFERAY_RELEASE_GIT_SHA} tag exists on remote."
	elif [ -n "$(git ls-remote origin refs/heads/"${LIFERAY_RELEASE_GIT_SHA}")" ]
	then
		echo "${LIFERAY_RELEASE_GIT_SHA} branch exists on remote."

		git fetch -f origin "${LIFERAY_RELEASE_GIT_SHA}:${LIFERAY_RELEASE_GIT_SHA}"
	else
		lc_log ERROR "${LIFERAY_RELEASE_GIT_SHA} does not exist." 

		#
		# TODO Exit.
		#
	fi

	git clean -dfx

	git checkout "${LIFERAY_RELEASE_GIT_SHA}"

	git status

	echo "${LIFERAY_RELEASE_GIT_SHA}" > "${_BUILD_DIR}"/sha-liferay-portal-ee
}

function update_release_tool_git {
	lc_cd "${_PROJECTS_DIR}"/liferay-release-tool-ee

	git clean -df
	git reset --hard

	local release_tool_sha=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.tool.sha")

	if [ ! -n "${release_tool_sha}" ]
	then
		echo "The release.tool.sha property is missing from the release.properties file in the liferay-portal-ee repository. Use a SHA which is compatible with this builder and includes both release.tool.dir and release.tool.sha properties."

		return 1
	fi

	if [ -e "${_BUILD_DIR}"/sha-liferay-release-tool-ee ] && [ $(cat "${_BUILD_DIR}"/sha-liferay-release-tool-ee) == "${release_tool_sha}" ]
	then
		echo "${release_tool_sha} is already checked out, skipping the git checkout step."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	git fetch --all --tags --prune || return 1
	git checkout origin/"${release_tool_sha}" || return 1

	echo "${release_tool_sha}" > "${_BUILD_DIR}"/sha-liferay-release-tool-ee
}