#!/bin/bash

function clone_repository {
	if [ -e /opt/liferay/dev/projects/${1} ]
	then
		return ${SKIPPED}
	fi

	mkdir -p /opt/liferay/dev/projects/
	cd /opt/liferay/dev/projects/

	git clone git@github.com:liferay/${1}.git
}

function compile_dxp {
	if [ -e ${BUILD_DIR}/built-sha ] && [ $(cat ${BUILD_DIR}/built-sha) == ${NARWHAL_GIT_SHA} ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the compile_dxp step."

		return ${SKIPPED}
	fi

	cd /opt/liferay/dev/projects/liferay-portal-ee

	ant all

	local exit_code=${?}

	if [ "${exit_code}" -eq 0 ]
	then
		echo "${NARWHAL_GIT_SHA}" >${BUILD_DIR}/built-sha
	fi

	return ${exit_code}
}

function create_folders {
	BUILD_DIR=/opt/liferay/builds/${NARWHAL_BUILD_ID}

	mkdir -p ${BUILD_DIR}
}

function get_dxp_version {
	cd /opt/liferay/dev/projects/liferay-portal-ee

	local major=$(cat release.properties | grep -F "release.info.version.major[master-private]=")
	local minor=$(cat release.properties | grep -F "release.info.version.minor[master-private]=")
	local bug_fix=$(cat release.properties | grep -F "release.info.version.bug.fix[master-private]=")
	local trivial=$(cat release.properties | grep -F "release.info.version.trivial=")

	echo ${major##*=}.${minor##*=}.${bug_fix##*=}-u${trivial##*=}
}

function git_update {
	if [ -e ${BUILD_DIR}/built-sha ] && [ $(cat ${BUILD_DIR}/built-sha) == ${NARWHAL_GIT_SHA} ]
	then
		echo "${NARWHAL_GIT_SHA} is already built in the ${BUILD_DIR}, skipping the git checkout step."

		return ${SKIPPED}
	fi

	cd /opt/liferay/dev/projects/liferay-portal-ee

	git fetch upstream --tags

	git clean -df
	git reset --hard
	git checkout "${NARWHAL_GIT_SHA}"
}

function main {
	SKIPPED=5

	create_folders

	time_run setup_ssh

	time_run clone_repository liferay-binaries-cache-2020 &
	time_run clone_repository liferay-portal-ee

	wait

	time_run git_update

	time_run pre_compile_setup

	DXP_VERSION=$(get_dxp_version)

	time_run prepare_update &

	time_run compile_dxp

	wait

	sleep 600
}

function pre_compile_setup {
	cd /opt/liferay/dev/projects/liferay-portal-ee

	if [ -e "build.profile-dxp.properties" ]
	then
		echo "build.profile-dxp.properties exists, skipping pre_compile_setup."

		return ${SKIPPED}
	fi

	ant setup-profile-dxp
}

function prepare_update {
	if [ -e /opt/liferay/bundles/${DXP_VERSION} ]
	then
		echo "Bundle already exists in /opt/liferay/bundles/${DXP_VERSION}."

		return
	fi

	echo "Download will happen here once we remove lpkgs. For now, build manually and place the buit version to the bundles folder."

	return 1
}

function setup_ssh {
	mkdir -p ${HOME}/.ssh

	ssh-keyscan -t rsa github.com >> ${HOME}/.ssh/known_hosts

	echo "${NARWHAL_GITHUB_SSH_KEY}" > ${HOME}/.ssh/id_rsa
	chmod 600 ${HOME}/.ssh/id_rsa
}

function echo_time {
	local seconds=${1}

	printf '%02dh:%02dm:%02ds' $((seconds/3600)) $((seconds%3600/60)) $((secons%60))
}

function time_run {
	local run_id=$(echo "${@}" | tr " " "_")
	local start_time=$(date +%s)

	local log_file=${BUILD_DIR}/build_${start_time}_${run_id}.txt

	echo ">>> Starting the \"${@}\" phase. Log: ${log_file}. $(date)"

	${@} &>${log_file}

	local exit_code=${?}

	local end_time=$(date +%s)

	if [ ${exit_code} == ${SKIPPED} ]
	then
		echo ">>> Skipped \"${@}\". $(date)"
	else
		local seconds=$((end_time - start_time))

		echo ">>> Finished \"${@}\" in $(echo_time ${seconds}). Exit code ${exit_code}. $(date)"

		if [ "${exit_code}" -gt 0 ]
		then
			echo "${@} exited with error, full log file: ${log_file}. Printing the last 100 lines:"

			tail -n 100 "${log_file}"
		fi
	fi
}

main