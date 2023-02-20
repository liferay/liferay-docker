#!/bin/bash

function add_file {
	file_dir=$(dirname ${1})

	mkdir -p ${BUILD_DIR}/hotfix/binaries/${file_dir}

	cp ${PATCHED_DIR}/${1} ${BUILD_DIR}/hotfix/binaries/${file_dir}
}

function calculate_checksums {
	cd ${BUILD_DIR}/hotfix/binaries/

	for file in $(find .)
	do
		md5sum ${file} >> ../checksums.txt
	done
}

function clone_repository {
	if [ -e /opt/liferay/dev/projects/${1} ]
	then
		return ${SKIPPED}
	fi

	mkdir -p /opt/liferay/dev/projects/
	cd /opt/liferay/dev/projects/

	git clone git@github.com:liferay/${1}.git
}

function compare_jars {
	jar1=${PATCHED_DIR}/${1}
	jar2=${UPDATE_DIR}/${1}

	function list_file {
		unzip -v ${1} | \
			# Remove heades and footers
			grep "Defl:N" | \
			# Remove 0 byte files
			grep -v 00000000 | \
			grep -v "META-INF/MANIFEST.MF" | \
			# There's a date included in this file
			grep -v "pom.properties" | \
			grep -v "source-classes-mapping.txt" | \
			# We should not include the util-*.jar changes, unless they changed
			# TODO: method to include portal-impl.jar when the util-* jars changed.
			grep -v "com/liferay/portal/deploy/dependencies/" | \
			# TODO: change portal not to update this file every time
			grep -v "META-INF/system.packages.extra.mf" | \
			# TODO: Figure out what to do with osgi/modules/com.liferay.sharepoint.soap.repository.jar
			grep -v "ws.jar" | \
			# Remove the date
			sed -e "s/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]//"
	}

	local file_changes=$((
		list_file ${jar1}
		list_file ${jar2}
	) | sort | uniq -c)

	if [ $(echo "${file_changes}" | grep "Defl:N" | wc -l) -eq 0 ]
	then
		return 2
	fi

	matches=$(echo "${file_changes}" | sed -e "s/\ *\([0-9][0-9]*\).*/\\1/" | sort | uniq)

	if [ "${matches}" != "2" ]
	then
		echo "Changes in ${1}: "
		echo "${file_changes}" | sed -e "s/\ *\([0-9][0-9]*\)/\\1/" | grep -v "^2 "

		return 0
	else
		return 1
	fi
}

function compile_dxp {
	PATCHED_DIR=/opt/liferay/dev/projects/bundles

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
	BUILD_DIR=/opt/liferay/build/

	mkdir -p ${BUILD_DIR}

	echo 0 > ${BUILD_DIR}/.step
}

function create_hotfix {
	rm -fr ${BUILD_DIR}/hotfix
	mkdir -p ${BUILD_DIR}/hotfix

	diff -rq ${PATCHED_DIR} ${UPDATE_DIR} | grep -v "/work/Catalina" | while read change
	do
		if (echo ${change} | grep "^Only in ${UPDATE_DIR}" &>/dev/null)
		then
			local deleted_file=${change#Only in }
			deleted_file=$(echo ${deleted_file} | sed -e "s#: #/#" | sed -e "s#${UPDATE_DIR}##")
			deleted_file=${deleted_file#/}
			echo ${deleted_file}

			if (in_scope ${deleted_file})
			then
				echo "Deleted ${deleted_file}"

				echo "${deleted_file}" >> ${BUILD_DIR}/hotfix/deleted_files.txt
			fi
		elif (echo ${change} | grep "^Only in ${PATCHED_DIR}" &>/dev/null)
		then
			local new_file=${change#Only in }
			new_file=$(echo ${new_file} | sed -e "s#: #/#" | sed -e "s#${PATCHED_DIR}##")
			new_file=${new_file#/}

			if (in_scope ${new_file})
			then
				echo "New file ${new_file}"
				add_file ${new_file}

				echo "${new_file}" >> ${BUILD_DIR}/hotfix/new_files.txt
			fi
		else
			local changed_file=${change#Files }
			changed_file=${changed_file%% *}
			changed_file=$(echo ${changed_file} | sed -e "s#${PATCHED_DIR}##")
			changed_file=${changed_file#/}

			if (in_scope ${changed_file})
			then
				if (echo ${changed_file} | grep -q ".[jw]ar$")
				then
					manage_jar ${changed_file} &
				else
					add_file ${changed_file}
				fi
			fi
		fi
	done
}

function echo_time {
	local seconds=${1}

	printf '%02dh:%02dm:%02ds' $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
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

	if (git remote | grep -q upstream)
	then
		git fetch upstream --tags
	else
		git fetch origin --tags
	fi

	git clean -df
	git reset --hard
	git checkout "${NARWHAL_GIT_SHA}"
}

function in_scope {
	if (echo ${1} | grep -q "^osgi/") || (echo ${1} | grep -q "^tomcat-.*/webapps/ROOT/")
	then
		return 0
	else
		return 1
	fi
}

function main {
	SKIPPED=5

	local start_time=$(date +%s)

	create_folders

	time_run setup_ssh

	time_run clone_repository liferay-binaries-cache-2020 &
	time_run clone_repository liferay-portal-ee

	wait

	time_run git_update

	time_run pre_compile_setup

	DXP_VERSION=$(get_dxp_version)
	UPDATE_DIR=/opt/liferay/bundles/${DXP_VERSION}

	time_run prepare_update &

	time_run compile_dxp

	wait

	time_run create_hotfix

	time_run calculate_checksums

	time_run package

	local end_time=$(date +%s)
	local seconds=$((end_time - start_time))

	echo ">>> Completed hotfix building process in $(echo_time ${seconds}). $(date)"
}

function manage_jar {
	if (compare_jars ${1})
	then
		echo "Changed .jar file: ${1}"

		add_file ${1}
	fi
}

function next_step {
	local step=$(cat ${BUILD_DIR}/.step)

	step=$((step + 1))

	echo ${step} > ${BUILD_DIR}/.step

	printf '%02d' ${step}
}

function package {
	cd ${BUILD_DIR}/hotfix

	zip -r ../liferay-hotfix-${NARWHAL_BUILD_ID}.zip *

	cd ..

	rm -fr hotfix
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
	if [ -e ${UPDATE_DIR} ]
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

function time_run {
	local run_id=$(echo "${@}" | tr " " "_")
	local start_time=$(date +%s)

	local log_file=${BUILD_DIR}/build_${start_time}_step_$(next_step)_${run_id}.txt

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

			exit ${exit_code}
		fi
	fi
}

main