#!/bin/bash

function add_licensing {
	lcd "/opt/liferay/dev/projects/liferay-portal-ee/tools/release/licensing"

	ant -Dext.dir=/opt/liferay/dev/projects/liferay-portal-ee/tools/release/licensing -Dportal.dir=/opt/liferay/dev/projects/liferay-portal-ee -f build-release-license.xml
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

function compile_dxp {
	if [ -e "${BUILD_DIR}"/built-sha ] && [ $(cat "${BUILD_DIR}"/built-sha) == "${NARWHAL_GIT_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the compile_dxp step."

		return "${SKIPPED}"
	fi

	lcd /opt/liferay/dev/projects/liferay-portal-ee

	ant all

	local exit_code=${?}

	if [ "${exit_code}" -eq 0 ]
	then
		echo "${NARWHAL_GIT_SHA}" > "${BUILD_DIR}"/built-sha
	fi

	return ${exit_code}
}

function create_folders {
	BUILD_DIR=/opt/liferay/build

	mkdir -p "${BUILD_DIR}"

	echo 0 > "${BUILD_DIR}"/.step

	mkdir -p /opt/liferay/download-cache
}

function download {
	url=${1}
	file=${2}

	if [ -e "${file}" ]
	then
		echo "Skipping the download of ${url} as it already exists."

		return
	fi

	cache_file=/opt/liferay/download-cache/${url%%.*://}

	if [ -e "${cache_file}" ]
	then
		echo "Copying file from cache: ${cache_file}"

		cp "${cache_file}" "${file}"
	fi

	echo "Downloading ${url}"

	if (! curl "${url}" --output "${cache_file}_temp" --silent)
	then
		echo "Downloading ${url} as unsuccessful, exiting."

		return 4
	else
		mv "${cache_file}_temp" "${cache_file}"

		cp "${cache_file}" "${file}"
	fi
}

function echo_time {
	local seconds=${1}

	printf '%02dh:%02dm:%02ds' $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

function get_dxp_version {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	local major=$(grep -F "release.info.version.major[master-private]=" release.properties)
	local minor=$(grep -F "release.info.version.minor[master-private]=" release.properties)
	local bug_fix=$(grep -F "release.info.version.bug.fix[master-private]=" release.properties)
	local trivial=$(grep -F "release.info.version.trivial=" release.properties)

	echo "${major##*=}.${minor##*=}.${bug_fix##*=}-u${trivial##*=}"
}

function git_update {
	if [ -e "${BUILD_DIR}"/built-sha ] && [ $(cat "${BUILD_DIR}"/built-sha) == "${NARWHAL_GIT_SHA}" ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the git checkout step."

		return "${SKIPPED}"
	fi

	lcd /opt/liferay/dev/projects/liferay-portal-ee

	git fetch origin --tags
	git clean -df
	git reset --hard
	git checkout "${NARWHAL_GIT_SHA}"
}

function lcd {
	cd "${1}" || exit 3
}

function main {
	SKIPPED=5
	BUNDLES_DIR=/opt/liferay/dev/projects/bundles

	local start_time=$(date +%s)

	create_folders

	time_run setup_ssh

	time_run clone_repository liferay-binaries-cache-2020 &
	time_run clone_repository liferay-portal-ee
	wait

	time_run setup_remote

	time_run git_update

	time_run pre_compile_setup

	time_run add_licensing

	DXP_VERSION=$(get_dxp_version)
	UPDATE_DIR=/opt/liferay/bundles/"${DXP_VERSION}"

	#time_run compile_dxp

	if [ "${NARWHAL_OUTPUT}" == "release" ]
	then
		source /usr/local/bin/release_functions.sh

		time_run download_released_files
	else
		source /usr/local/bin/hotfix_functions.sh

		time_run create_hotfix

		time_run calculate_checksums

		time_run create_documentation

		time_run package
	fi

	local end_time=$(date +%s)
	local seconds=$((end_time - start_time))

	echo ">>> Completed hotfix building process in $(echo_time ${seconds}). $(date)"
}

function next_step {
	local step=$(cat "${BUILD_DIR}"/.step)

	step=$((step + 1))

	echo ${step} > "${BUILD_DIR}"/.step

	printf '%02d' ${step}
}

function pre_compile_setup {
	lcd /opt/liferay/dev/projects/liferay-portal-ee

	if [ -e "build.profile-dxp.properties" ]
	then
		echo "build.profile-dxp.properties exists, skipping pre_compile_setup."

		return "${SKIPPED}"
	fi

	ant setup-profile-dxp
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

		return ${SKIPPED}
	fi

	git remote rm origin

	git remote add origin git@github.com:${NARWHAL_REMOTE}/liferay-portal-ee
}

function setup_ssh {
	mkdir -p "${HOME}"/.ssh

	ssh-keyscan github.com >> "${HOME}"/.ssh/known_hosts

	echo "${NARWHAL_GITHUB_SSH_KEY}" > "${HOME}"/.ssh/id_rsa
	chmod 600 "${HOME}"/.ssh/id_rsa
}

function time_run {
	local run_id=$(echo "${@}" | tr " " "_")
	local start_time=$(date +%s)

	local log_file="${BUILD_DIR}/build_${start_time}_step_$(next_step)_${run_id}.txt"

	echo "$(date) > ${*}"

	"${@}" &> "${log_file}"

	local exit_code=${?}

	local end_time=$(date +%s)

	if [ "${exit_code}" == "${SKIPPED}" ]
	then
		echo "$(date) < ${*} - skip"
	else
		local seconds=$((end_time - start_time))

		
		if [ "${exit_code}" -gt 0 ]
		then
			echo "$(date) ! ${*} exited with error in $(echo_time ${seconds}) (exit code: ${exit_code}), full log file: ${log_file}. Printing the last 100 lines:"

			tail -n 100 "${log_file}"

			exit ${exit_code}
		else 
			echo "$(date) < ${*} - success in $(echo_time ${seconds})"
		fi
	fi
}

main