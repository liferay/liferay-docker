#!/bin/bash

function add_file_to_hotfix {
	local file_name=$(transform_file_name "${1}")

	local file_dir=$(dirname "${file_name}")

	mkdir -p "${_BUILD_DIR}/hotfix/binaries/${file_dir}"

	cp "${_BUNDLES_DIR}/${1}" "${_BUILD_DIR}/hotfix/binaries/${file_dir}"
}

function add_portal_patcher_properties_jar {
	lc_cd "${_BUILD_DIR}"

	mkdir portal-patcher-properties

	lc_cd "${_BUILD_DIR}/portal-patcher-properties"

	touch manifest

	(
		echo "fixed.issues=${LIFERAY_RELEASE_FIXED_ISSUES}"
		echo "installed.patches=${HOTFIX_NAME}"
	)  > patcher.properties

	jar cfm portal-patcher-properties.jar manifest patcher.properties

	if [ -e "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/" ]
	then
		cp portal-patcher-properties.jar "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/"
	else
		cp portal-patcher-properties.jar "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/lib/"
	fi
}

function add_hotfix_testing_code {
	if [ ! -n "${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" ]
	then
		echo "LIFERAY_RELEASE_HOTFIX_TEST_SHA is not set, not adding test code."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	if (! git show "${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" &>/dev/null)
	then
		echo "Running git fetch upstream tag \"${LIFERAY_RELEASE_HOTFIX_TEST_TAG}\""

		git fetch -v upstream tag "${LIFERAY_RELEASE_HOTFIX_TEST_TAG}" || return 1
	fi

	echo "Running git cherry-pick -n \"${LIFERAY_RELEASE_HOTFIX_TEST_SHA}\""

	git cherry-pick -n "${LIFERAY_RELEASE_HOTFIX_TEST_SHA}" || return 1
}

function calculate_checksums {
	if [ ! -e "${_BUILD_DIR}/hotfix/binaries/" ]
	then
		echo "There are no added files."

		return
	fi

	lc_cd "${_BUILD_DIR}/hotfix/binaries/"

	find . -type f -print0 | while IFS= read -r -d '' file
	do
		sha256sum "${file}" >> ../checksums
	done
}

function compare_jars {
	jar1=${_BUNDLES_DIR}/"${1}"
	jar2=${RELEASE_DIR}/"${1}"

	function list_file {
		unzip -v "${1}" | \
			# Remove heades and footers
			grep "Defl:N" | \
			# Remove 0 byte files
			grep -v 00000000 | \
			grep -v "META-INF/MANIFEST.MF" | \
			grep -v "pom.properties" | \
			grep -v "source-classes-mapping.txt" | \
			grep -v "previous-compilation-data.bin" | \
			# We should not include the util-*.jar changes, unless they changed
			# TODO: method to include portal-impl.jar when the util-* jars changed.
			grep -v "com/liferay/portal/deploy/dependencies/" | \
			# TODO: change portal not to update this file every time
			grep -v "META-INF/system.packages.extra.mf" | \
			# TODO: Figure out what to do with osgi/modules/com.liferay.sharepoint.soap.repository.jar
			grep -v "ws.jar" | \
			# Remove the date
			sed -e "s/[0-9][0-9][-]*[0-9][0-9][-]*[0-9][0-9][-]*[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]//"
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

function create_documentation {
	function write {
		echo -en "${1}" >> "${_BUILD_DIR}/hotfix/hotfix.json"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	writeln "{"
	writeln "    \"patch\": {"
	writeln "        \"id\": \"${LIFERAY_RELEASE_HOTFIX_ID}\""
	writeln "    },"
	writeln "    \"fixed-issues\": [\"LPS-1\", \"LPS-2\"],"
	writeln "    \"build\": {"
	writeln "        \"date\": \"$(date)\","
	writeln "        \"git-revision\": \"${GIT_SHA}\","
	writeln "        \"id\": \"219379428\","
	writeln "        \"builder-revision\": \"TBD\""
	writeln "    },"
	writeln "    \"requirement\": {"
	writeln "        \"patching-tool-version\": \"4000\","
	writeln "        \"product-version\": \"${_DXP_VERSION}\""
	writeln "    },"
	writeln "    \"added\" :["


	local first_line=true

	if [ -e "${_BUILD_DIR}"/hotfix/checksums ]
	then
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
		done < "${_BUILD_DIR}"/hotfix/checksums
		writeln ""
	fi

	writeln "    ],"

	writeln "    \"removed\" :["

	if [ -e "${_BUILD_DIR}"/hotfix/removed_files ]
	then
		first_line=true

		while read -r file
		do
			if [ "${first_line}" = true ]
			then
				first_line=false
			else
				writeln ","
			fi
			writeln "        {"
			writeln "            \"path\": \"${file}\""
			write "        }"
		done < "${_BUILD_DIR}"/hotfix/removed_files

		writeln ""
	fi

	writeln "    ]"

	writeln "}"
}

function create_hotfix {
	rm -fr "${_BUILD_DIR}"/hotfix
	mkdir -p "${_BUILD_DIR}"/hotfix

	echo "Comparing ${_BUNDLES_DIR} and ${RELEASE_DIR}"

	echo "Full diff:"

	diff -rq "${_BUNDLES_DIR}" "${RELEASE_DIR}" | grep -v /work/Catalina

	diff -rq "${_BUNDLES_DIR}" "${RELEASE_DIR}" | grep -v /work/Catalina | while read -r change
	do
		if (echo "${change}" | grep "^Only in ${RELEASE_DIR}" &>/dev/null)
		then
			local removed_file=${change#Only in }
			removed_file=$(echo "${removed_file}" | sed -e "s#: #/#" | sed -e "s#${RELEASE_DIR}##")
			removed_file=${removed_file#/}
			echo "${removed_file}"

			if [ ! -f "${RELEASE_DIR}/${removed_file}" ]
			then
				echo "Skipping ${removed_file} as it's not a file"

				continue
			fi

			if (in_hotfix_scope "${removed_file}")
			then
				echo "Removed ${removed_file}"

				transform_file_name "${removed_file}" >> "${_BUILD_DIR}"/hotfix/removed_files
			fi
		elif (echo "${change}" | grep "^Only in ${_BUNDLES_DIR}" &>/dev/null)
		then
			local new_file=${change#Only in }
			new_file=$(echo "${new_file}" | sed -e "s#: #/#" | sed -e "s#${_BUNDLES_DIR}##")
			new_file=${new_file#/}

			if [ ! -f "${_BUNDLES_DIR}/${new_file}" ]
			then
				echo "Skipping ${new_file} as it's not a file"

				continue
			fi

			if (in_hotfix_scope "${new_file}")
			then
				echo "New file ${new_file}"

				add_file_to_hotfix "${new_file}"
			fi
		else
			local changed_file=${change#Files }
			changed_file=${changed_file%% *}
			changed_file=$(echo "${changed_file}" | sed -e "s#${_BUNDLES_DIR}##")
			changed_file=${changed_file#/}

			if [ ! -f "${_BUNDLES_DIR}/${changed_file}" ]
			then
				echo "Skipping ${changed_file} as it's not a file"

				continue
			fi

			if (in_hotfix_scope "${changed_file}")
			then
				if (echo "${changed_file}" | grep -q ".[jw]ar$")
				then
					manage_jar "${changed_file}"
				else
					add_file_to_hotfix "${changed_file}"
				fi
			fi
		fi
	done
}

function in_hotfix_scope {
	if (echo "${1}" | grep -q "^tomcat/webapps/ROOT/")
	then
		return 0
	fi

	if (echo "${1}" | grep -q "^osgi/") && (! echo "${1}" | grep -q "^osgi/state") && (! echo "${1}" | grep -q "^osgi/war")
	then
		return 0
	fi

	return 1
}

function manage_jar {
	if (compare_jars "${1}")
	then
		echo "Changed .jar file: ${1}"

		add_file_to_hotfix "${1}"
	fi
}

function package_hotfix {
	lc_cd "${_BUILD_DIR}"/hotfix

	rm -f "../${_HOTFIX_FILE_NAME}" checksums removed_files

	zip -r "../${_HOTFIX_FILE_NAME}" ./*

	lc_cd "${_BUILD_DIR}"

	rm -fr hotfix
}

function prepare_release_dir {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	RELEASE_DIR="${_RELEASES_DIR}/${_DXP_VERSION}"

	local release7z

	if [ -e "${_TEST_RELEASE_DIR}" ] && [ $(find "${_TEST_RELEASE_DIR}" -type f -printf "%f\n" | wc -l) -eq 1 ]
	then
		lc_cd "${_TEST_RELEASE_DIR}"

		local release_file=$(find . -type f -printf "%f\n")

		RELEASE_DIR="${_RELEASES_DIR}/${release_file%%.7z}"

		release7z="${_TEST_RELEASE_DIR}/${release_file}"
	else
		echo "Release is not available, download is not yet an option."

		return 1
	fi

	if [ -e "${RELEASE_DIR}" ]
	then
		echo "${RELEASE_DIR} is already available."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir -p "${RELEASE_DIR}"

	lc_cd "${RELEASE_DIR}"

	7z x "${release7z}"

	mv liferay-dxp/* .
	mv liferay-dxp/.* . &> /dev/null

	rm -fr liferay-dxp/
}

function set_hotfix_name {
	_HOTFIX_FILE_NAME=liferay-dxp-${_DXP_VERSION}-hotfix-"${LIFERAY_RELEASE_HOTFIX_ID}".zip
	HOTFIX_NAME=hotfix-"${LIFERAY_RELEASE_HOTFIX_ID}"
}

function sign_hotfix {
	lc_cd "${_BUILD_DIR}"/hotfix

	if [ ! -n "${LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE}" ]
	then
		lc_log INFO "LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE environment variable is not set."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ ! -e "${LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE}" ]
	then
		lc_log ERROR "LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE does not point to a valid file."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	openssl dgst -passin env:LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_PASSWORD -out hotfix.sign -sha256 -sign "${LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE}"  hotfix.json
}

function transform_file_name {
	local file_name=$(echo "${1}" | sed -e s#osgi/#OSGI_BASE_PATH/#)

	file_name=$(echo "${file_name}" | sed -e s#tomcat/webapps/ROOT#WAR_PATH#)

	echo "${file_name}"
}