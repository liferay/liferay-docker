#!/bin/bash

source ./_liferay_common.sh

function main {
	local workspace_dir=${PWD}

	local current_job=$(basename "${PWD}")

	lc_log INFO "Cleaning workspace for job ${current_job}."

	if [ "${current_job}" == "build-hotfix" ] ||
	   [ "${current_job}" == "build-release" ] ||
	   [ "${current_job}" == "build-release-nightly" ] ||
	   [ "${current_job}" == "release-gold" ]
	then
		local buildkit_container_name=$(docker ps --filter "name=buildkit" --format "{{.Names}}")

		if [ -n "${buildkit_container_name}" ]
		then
			docker stop "${buildkit_container_name}" &> /dev/null

			docker rm --force "${buildkit_container_name}" &> /dev/null
		fi

		local buildkit_volume_name=$(docker volume ls --filter "name=buildkit" --format "{{.Name}}")

		if [ -n "${buildkit_volume_name}" ]
		then
			docker volume rm --force "${buildkit_volume_name}" &> /dev/null
		fi

		docker system prune --all --force &> /dev/null

		find . /opt/dev/projects/github/liferay-docker \
			-maxdepth 1 \
			-regextype posix-extended \
			-regex ".*/(logs-[0-9]{12}|temp-.*)$" \
			-type d \
			-exec rm --force --recursive {} \; &> /dev/null

		find /tmp \
			-mindepth 1 \
			-regextype posix-extended \
			-regex ".*/(dart-sass|yarn).*" \
			-type d \
			-exec rm --force --recursive {} \; &> /dev/null

		local liferay_repository=""

		if [ -f "${workspace_dir}/release/release-data/build/liferay-portal-ee.sha" ]
		then
			liferay_repository="liferay-portal-ee"
		elif [ -f "${workspace_dir}/release/release-data/build/liferay-portal.sha" ]
		then
			liferay_repository="liferay-portal"
		fi

		for repository in liferay-binaries-cache-2020 "${liferay_repository}"
		do
			_clean_up_repository "${repository}"
		done

		rm --force --recursive "${workspace_dir}/downloads"
		rm --force --recursive "${workspace_dir}/release/release-data"
	elif [ "${current_job}" == "crowdin-sync" ]
	then
		rm --force --recursive "${workspace_dir}/crowdin/logs"

		_clean_up_repository "liferay-portal"
	elif [ "${current_job}" == "source-code-sharing" ]
	then
		rm --force --recursive "${workspace_dir}/narwhal/source_code_sharing/liferay-portal-ee"
	fi

	local liferay_common_cache_dir="${HOME}/.liferay-common-cache"

	if [ -d "${liferay_common_cache_dir}" ] &&
	   [[ "$(du --bytes --summarize "${liferay_common_cache_dir}" | cut --fields=1)" -gt 10737418240 ]]
	then
		find "${liferay_common_cache_dir}" \
			-mindepth 1 \
			-exec rm --force --recursive {} \; &> /dev/null
	fi
}

function _clean_up_repository {
	if [ -z "${1}" ]
	then
		return
	fi

	lc_cd "/opt/dev/projects/github/${1}"

	git clean -dfx &> /dev/null

	git gc &> /dev/null
}

main