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
		echo "installed.patches=${_HOTFIX_NAME}"
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
	jar2=${_RELEASE_DIR}/"${1}"

	function compare_property_in_packaged_file {
		local jar1="${1}"
		local jar2="${2}"
		local packaged_file="${3}"
		local property="${4}"

		local value1=$(unzip -p "${jar1}" "${packaged_file}" | sed -z -r 's@\r?\n @@g' | grep -w "${property}")
		local value2=$(unzip -p "${jar2}" "${packaged_file}" | sed -z -r 's@\r?\n @@g' | grep -w "${property}")

		if [ "${value1}" == "${value2}" ]
		then
			return 0
		fi

		return 1
	}

	function list_file {
		unzip -v "${1}" | \
			# Remove heades and footers
			grep "Defl:N" | \
			# Remove 0 byte files
			grep -v 00000000 | \
			grep -v "pom.properties" | \
			grep -v "source-classes-mapping.txt" | \
			grep -v "_jsp.class" | \
			grep -v "_jsp.java" | \
			grep -v "previous-compilation-data.bin" | \
			# TODO method to include portal-impl.jar when the util-* jars changed.
			grep -v "com/liferay/portal/deploy/dependencies/" | \
			# TODO change portal not to update this file every time
			grep -v "META-INF/system.packages.extra.mf" | \
			# TODO Figure out what to do with osgi/modules/com.liferay.sharepoint.soap.repository.jar
			grep -v "ws.jar" | \
			sed -e "s/[0-9][0-9][-]*[0-9][0-9][-]*[0-9][0-9][-]*[0-9][0-9]\ [0-9][0-9]:[0-9][0-9]//"
	}

	local files_list=$( (
		list_file "${jar1}"
		list_file "${jar2}"
	) | sort | uniq -c)

	local files_count=$(echo "${files_list}" | grep -c "Defl:N")

	if [ "${files_count}" -eq 0 ]
	then
		lc_log ERROR "No files found in the jar files, unknown error."

		exit 2
	fi

	local changed_files_list=$(echo "${files_list}" | awk '($1 == 1) && ($3 == "Defl:N") { print $7 }' | uniq)

	if [ -n "${changed_files_list}" ]
	then
		if (echo "${changed_files_list}" | grep -q "META-INF/MANIFEST.MF")
		then
			if (compare_property_in_packaged_file "${jar1}" "${jar2}" "META-INF/MANIFEST.MF" "Export-Package")
			then
				changed_files_list=$(echo "${changed_files_list}" | sed "/META-INF\/MANIFEST.MF/d")
			fi
		fi

		if [ -n "${changed_files_list}" ]
		then
			lc_log INFO "Changes in ${1}: "
			lc_log INFO "${changed_files_list}" | sed "s/^/    /"
			lc_log INFO ""

			return 0
		else
			return 1
		fi
	fi
}

function copy_release_info_date {
	local build_date=$(unzip -p "${_RELEASE_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/portal-impl.jar" META-INF/MANIFEST.MF | grep "Liferay-Portal-Build-Date:")

	build_date=${build_date#Liferay-Portal-Build-Date: }

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	sed -i -e "s/release.info.date=.*/release.info.date=$(date -d "${build_date}" +"%B %d, %Y")/" release.properties
}

function create_documentation {
	function write {
		echo -en "${1}" >> "${_BUILD_DIR}/hotfix/hotfix.json"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	local first_line=true

	writeln "{"
	writeln "    \"patch\": {"
	writeln "        \"id\": \"${LIFERAY_RELEASE_HOTFIX_ID}\""
	writeln "    },"
	writeln "    \"fixed-issues\": ["

	if [ -n "${LIFERAY_RELEASE_HOTFIX_FIXED_ISSUES}" ]
	then
		echo "${LIFERAY_RELEASE_HOTFIX_FIXED_ISSUES}" | tr ',' '\n' | while read -r line
		do
			if [ "${first_line}" = true ]
			then
				first_line=false

				write "        "
			else
				write ","
			fi

			write "\"${line}\""
		done

		writeln ""
	fi

	writeln "    ],"
	writeln "    \"build\": {"
	writeln "        \"builder-revision\": \"${_BUILDER_SHA}\"",
	writeln "        \"date\": \"$(date)\","
	writeln "        \"git-revision\": \"${_GIT_SHA}\","
	writeln "        \"id\": \"${LIFERAY_RELEASE_HOTFIX_BUILD_ID}\""
	writeln "    },"
	writeln "    \"requirement\": {"
	writeln "        \"patching-tool-version\": \"4000\","
	writeln "        \"product-version\": \"${_PRODUCT_VERSION}\""
	writeln "    },"
	writeln "    \"added\" :["

	first_line=true

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

	echo "Comparing ${_BUNDLES_DIR} and ${_RELEASE_DIR}"

	echo "Full diff:"

	diff -rq "${_BUNDLES_DIR}" "${_RELEASE_DIR}" | grep -v /work/Catalina

	diff -rq "${_BUNDLES_DIR}" "${_RELEASE_DIR}" | grep -v /work/Catalina | while read -r change
	do
		if (echo "${change}" | grep "^Only in ${_RELEASE_DIR}" &>/dev/null)
		then
			local removed_file=${change#Only in }
			removed_file=$(echo "${removed_file}" | sed -e "s#: #/#" | sed -e "s#${_RELEASE_DIR}##")
			removed_file=${removed_file#/}
			echo "${removed_file}"

			if [ ! -f "${_RELEASE_DIR}/${removed_file}" ]
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

	_RELEASE_DIR="${_RELEASES_DIR}/${_PRODUCT_VERSION}"

	local release7z

	if [ -e "${_TEST_RELEASE_DIR}" ] && [ $(find "${_TEST_RELEASE_DIR}" -type f -printf "%f\n" | wc -l) -eq 1 ]
	then
		lc_cd "${_TEST_RELEASE_DIR}"

		local release_file=$(find . -type f -printf "%f\n")

		_RELEASE_DIR="${_RELEASES_DIR}/${release_file%%.7z}"

		release7z="${_TEST_RELEASE_DIR}/${release_file}"
	fi

	if [ -e "${_RELEASE_DIR}" ]
	then
		if [ ! -e "${_RELEASE_DIR}/tomcat" ]
		then
			echo "${_RELEASE_DIR} does not have a tomcat directory, deleting."

			rm -fr "${_RELEASE_DIR}"
		else
			echo "${_RELEASE_DIR} is already available."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi
	fi

	rm -fr "${_RELEASE_DIR}.tmp"

	mkdir -p "${_RELEASE_DIR}.tmp"

	lc_cd "${_RELEASE_DIR}.tmp"

	if [ -n "${release7z}" ]
	then
		7z x "${release7z}"
	else
		lc_download "https://releases-cdn.liferay.com/dxp/${_PRODUCT_VERSION}/$(lc_curl "https://releases-cdn.liferay.com/dxp/${_PRODUCT_VERSION}/.lfrrelease-tomcat-bundle")" liferay-dxp.7z

		7z x ./liferay-dxp.7z

		rm -f ./liferay-dxp.7z
	fi

	shopt -s dotglob

	mv liferay-dxp/* .

	shopt -u dotglob

	rm -fr liferay-dxp/

	mv "${_RELEASE_DIR}.tmp" "${_RELEASE_DIR}"
}

function set_hotfix_name {
	_HOTFIX_FILE_NAME=liferay-dxp-${_PRODUCT_VERSION}-hotfix-"${LIFERAY_RELEASE_HOTFIX_ID}".zip
	_HOTFIX_NAME=hotfix-"${LIFERAY_RELEASE_HOTFIX_ID}"
}

function sign_hotfix {
	lc_cd "${_BUILD_DIR}"/hotfix

	if [ ! -n "${LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE}" ]
	then
		lc_log INFO "Set the environment variable LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE."

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