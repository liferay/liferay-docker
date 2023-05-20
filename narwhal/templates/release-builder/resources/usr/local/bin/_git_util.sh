#!/bin/bash

function clean_portal_git {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	git clean -df
	git reset --hard

	GIT_SHA=$(git rev-parse HEAD)
	GIT_SHA_SHORT=$(git rev-parse --short HEAD)
}

function clone_repository {
	if [ -e /opt/liferay/dev/projects/"${1}" ]
	then
		return "${SKIPPED}"
	fi

	mkdir -p /opt/liferay/dev/projects/
	lcd /opt/liferay/dev/projects/

	git clone git@github.com:liferay/"${1}".git
}

function setup_git {
	mkdir -p "${HOME}"/.ssh

	ssh-keyscan github.com >> "${HOME}"/.ssh/known_hosts

	echo "${NARWHAL_GITHUB_SSH_KEY}" > "${HOME}"/.ssh/id_rsa
	chmod 600 "${HOME}"/.ssh/id_rsa

	git config --global user.email "er-hu@liferay.com"
	git config --global user.name "Release Builder"
}

function setup_remote {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	if [ ! -n "${NARWHAL_REMOTE}" ]
	then
		NARWHAL_REMOTE=liferay
	fi

	if (git remote get-url origin | grep -q "github.com:${NARWHAL_REMOTE}/")
	then
		echo "Remote is already set up."

		return "${SKIPPED}"
	fi

	git remote rm origin

	git remote add origin git@github.com:${NARWHAL_REMOTE}/liferay-portal-ee
}

function update_portal_git {
	trap "return 1" ERR

	lcd /opt/liferay/dev/projects/liferay-portal-ee

	if [ -e "${BUILD_DIR}"/sha-liferay-portal-ee ] && [ $(cat "${BUILD_DIR}"/sha-liferay-portal-ee) == "${NARWHAL_GIT_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already checked out, skipping the git checkout step."

		return "${SKIPPED}"
	fi

	if [ -n "$(git ls-remote origin refs/tags/"${NARWHAL_GIT_SHA}")" ]
	then
		echo "${NARWHAL_GIT_SHA} tag exists on remote."

		git fetch origin tag "${NARWHAL_GIT_SHA}"
		git checkout "${NARWHAL_GIT_SHA}"
	elif [ -n "$(git ls-remote origin refs/heads/"${NARWHAL_GIT_SHA}")" ]
	then
		echo "${NARWHAL_GIT_SHA} branch exists on remote."

		git fetch origin "${NARWHAL_GIT_SHA}"
		git checkout "${NARWHAL_GIT_SHA}"
		git reset --hard
		git clean -fd
		git pull origin "${NARWHAL_GIT_SHA}"
		git reset --hard origin/"${NARWHAL_GIT_SHA}"
		git clean -fd
	fi

	echo "${NARWHAL_GIT_SHA}" > "${BUILD_DIR}"/sha-liferay-portal-ee
}

function update_release_tool_git {
	lcd /opt/liferay/dev/projects/liferay-release-tool-ee

	git clean -df
	git reset --hard

	local release_tool_sha=$(read_property /opt/liferay/dev/projects/liferay-portal-ee/release.properties "release.tool.sha")

	if [ ! -n "${release_tool_sha}" ]
	then
		echo "The release.tool.sha property is missing from the release.properties file in the liferay-portal-ee repository. Use a SHA which is compatible with this builder and includes both release.tool.dir and release.tool.sha properties."

		return 1
	fi

	if [ -e "${BUILD_DIR}"/sha-liferay-release-tool-ee ] && [ $(cat "${BUILD_DIR}"/sha-liferay-release-tool-ee) == "${release_tool_sha}" ]
	then
		echo "${release_tool_sha} is already checked out, skipping the git checkout step."

		return "${SKIPPED}"
	fi

	git fetch --all --tags --prune || return 1
	git checkout origin/"${release_tool_sha}" || return 1

	echo "${release_tool_sha}" > "${BUILD_DIR}"/sha-liferay-release-tool-ee
}
