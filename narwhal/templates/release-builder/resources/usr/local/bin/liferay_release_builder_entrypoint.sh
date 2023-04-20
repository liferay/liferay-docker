#!/bin/bash

function add_file {
	local file_name=$(transform_file_name "${1}")

	local file_dir=$(dirname "${file_name}")

	mkdir -p "${BUILD_DIR}/hotfix/binaries/${file_dir}"

	cp "${BUNDLES_DIR}/${1}" "${BUILD_DIR}/hotfix/binaries/${file_dir}"
}

function add_licensing {
	lcd "/opt/liferay/dev/projects/liferay-portal-ee/tools/release/licensing"

	ant -Dext.dir=/opt/liferay/dev/projects/liferay-portal-ee/tools/release/licensing -Dportal.dir=/opt/liferay/dev/projects/liferay-portal-ee -f build-release-license.xml
}

function calculate_checksums {
	lcd "${BUILD_DIR}/hotfix/binaries/"

	find . -print0 | while IFS= read -r -d '' file
	do
		md5sum "${file}" >> ../checksums
	done
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

function compare_jars {
	jar1=${BUNDLES_DIR}/"${1}"
	jar2=${UPDATE_DIR}/"${1}"

	function list_file {
		unzip -v "${1}" | \
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

	local file_changes=$( (
		list_file "${jar1}"
		list_file "${jar2}"
	) | sort | uniq -c)

	if [ $(echo "${file_changes}" | grep -c "Defl:N") -eq 0 ]
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

function create_documentation {
	function write {
		echo -en "${1}" >> "${BUILD_DIR}/hotfix/hotfix_documentation.json"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	writeln "{"
	writeln "    \"removed\" :["

	if [ -e "${BUILD_DIR}"/hotfix/removed_files ]
	then
		local first_line=true
		while read -r file
		do
			if [ "${first_line}" = true ]
			then
				first_line=false
			else
				writeln ","
			fi

			write "        \"file\": \"${file}\""
		done < "${BUILD_DIR}"/hotfix/removed_files

		writeln ""
	fi

	writeln "    ],"
	writeln "    \"added\" :["

	local first_line=true

	while read -r line
	do
		local checksum=${line%% *}
		local file=${line##* ./}
		if [ "${first_line}" = true ]
		then
			first_line=false
		else
			writeln ","
		fi

		writeln "        {"
		writeln "            \"path\": \"${file}\","
		writeln "            \"checksum\": \"${checksum}\""
		write "        }"
	done < "${BUILD_DIR}"/hotfix/checksums

	writeln ""

	writeln "    ],"
	writeln "    \"fixed-issues\": [\"LPS-1\", \"LPS-2\"],"
	writeln "    \"build\": {"
	writeln "        \"date\": \"$(date)\","
	writeln "        \"git-revision\": \"TBD\","
	writeln "        \"id\": \"219379428\","
	writeln "        \"builder-revision\": \"TBD\""
	writeln "    },"
	writeln "    \"patch\": {"
	writeln "        \"built-for\": \"TBD\","
	writeln "        \"id\": \"hotfix-1-7413\","
	writeln "        \"name\": \"hotfix-1\","
	writeln "        \"product\": \"7413\","
	writeln "        \"requirements\": \"${DXP_VERSION}\""
	writeln "    },"
	writeln "    \"patching-tool\": {"
	writeln "        \"incompatible-version-message\": \"Please update Patching Tool to version 4.0.2 or higher in order to use this patch.\","
	writeln "        \"version\": \"4002\""
	writeln "    }"
	writeln "}"
}

function create_folders {
	BUILD_DIR=/opt/liferay/build

	mkdir -p "${BUILD_DIR}"

	echo 0 > "${BUILD_DIR}"/.step
}

function create_hotfix {
	rm -fr "${BUILD_DIR}"/hotfix
	mkdir -p "${BUILD_DIR}"/hotfix

	diff -rq "${BUNDLES_DIR}" "${UPDATE_DIR}" | grep -v /work/Catalina | while read -r change
	do
		if (echo "${change}" | grep "^Only in ${UPDATE_DIR}" &>/dev/null)
		then
			local removed_file=${change#Only in }
			removed_file=$(echo "${removed_file}" | sed -e "s#: #/#" | sed -e "s#${UPDATE_DIR}##")
			removed_file=${removed_file#/}
			echo "${removed_file}"

			if (in_scope "${removed_file}")
			then
				echo "Removed ${removed_file}"

				transform_file_name "${removed_file}" >> "${BUILD_DIR}"/hotfix/removed_files
			fi
		elif (echo "${change}" | grep "^Only in ${BUNDLES_DIR}" &>/dev/null)
		then
			local new_file=${change#Only in }
			new_file=$(echo "${new_file}" | sed -e "s#: #/#" | sed -e "s#${BUNDLES_DIR}##")
			new_file=${new_file#/}

			if (in_scope "${new_file}")
			then
				echo "New file ${new_file}"
				add_file "${new_file}"
			fi
		else
			local changed_file=${change#Files }
			changed_file=${changed_file%% *}
			changed_file=$(echo "${changed_file}" | sed -e "s#${BUNDLES_DIR}##")
			changed_file=${changed_file#/}

			if (in_scope "${changed_file}")
			then
				if (echo "${changed_file}" | grep -q ".[jw]ar$")
				then
					manage_jar "${changed_file}" &
				else
					add_file "${changed_file}"
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

function in_scope {
	if (echo "${1}" | grep -q "^osgi/") || (echo "${1}" | grep -q "^tomcat-.*/webapps/ROOT/")
	then
		return 0
	else
		return 1
	fi
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

	time_run compile_dxp

	wait

	time_run create_hotfix

	time_run calculate_checksums

	time_run create_documentation

	time_run package

	local end_time=$(date +%s)
	local seconds=$((end_time - start_time))

	echo ">>> Completed hotfix building process in $(echo_time ${seconds}). $(date)"
}

function manage_jar {
	if (compare_jars "${1}")
	then
		echo "Changed .jar file: ${1}"

		add_file "${1}"
	fi
}

function next_step {
	local step=$(cat "${BUILD_DIR}"/.step)

	step=$((step + 1))

	echo ${step} > "${BUILD_DIR}"/.step

	printf '%02d' ${step}
}

function package {
	lcd "${BUILD_DIR}"/hotfix

	rm -f ../liferay-hotfix-"${NARWHAL_BUILD_ID}".zip checksums removed_files

	zip -r ../liferay-hotfix-"${NARWHAL_BUILD_ID}".zip ./*

	lcd "${BUILD_DIR}"

	rm -fr hotfix
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

function transform_file_name {
	local file_name=$(echo "${1}" | sed -e s#osgi/modules#MODULES_BASE_PATH#)

	file_name=$(echo "${file_name}" | sed -e s#tomcat.*/webapps/ROOT#WAR_PATH#)

	echo "${file_name}"
}

main