#!/bin/bash

function add_file {
	local file_name=$(transform_file_name "${1}")

	local file_dir=$(dirname "${file_name}")

	mkdir -p "${BUILD_DIR}/hotfix/binaries/${file_dir}"

	cp "${BUNDLES_DIR}/${1}" "${BUILD_DIR}/hotfix/binaries/${file_dir}"
}

function calculate_checksums {
	if [ ! -e "${BUILD_DIR}/hotfix/binaries/" ]
	then
		echo "There are no added files."

		return
	fi

	lcd "${BUILD_DIR}/hotfix/binaries/"

	find . -print0 | while IFS= read -r -d '' file
	do
		md5sum "${file}" >> ../checksums
	done
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

function create_documentation {
	function write {
		echo -en "${1}" >> "${BUILD_DIR}/hotfix/hotfix.json"
		echo -en "${1}"
	}

	function writeln {
		write "${1}\n"
	}

	writeln "{"
	writeln "    \"patch\": {"
	writeln "        \"built-for\": \"TBD\","
	writeln "        \"id\": \"${NARWHAL_BUILD_ID}\","
	writeln "    },"
	writeln "    \"fixed-issues\": [\"LPS-1\", \"LPS-2\"],"
	writeln "    \"build\": {"
	writeln "        \"date\": \"$(date)\","
	writeln "        \"git-revision\": \"${GIT_SHA}\","
	writeln "        \"id\": \"219379428\","
	writeln "        \"builder-revision\": \"TBD\""
	writeln "    },"
	writeln "    \"requirements\": {"
	writeln "        \"patching-tool-version\": \"4000\","
	writeln "        \"product-version\": \"${DXP_VERSION}\""
	writeln "    },"
	writeln "    \"added\" :["


	local first_line=true

	if [ -e "${BUILD_DIR}"/hotfix/checksums ]
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
		done < "${BUILD_DIR}"/hotfix/checksums
		writeln ""
	fi

	writeln "    ],"

	writeln "    \"removed\" :["

	if [ -e "${BUILD_DIR}"/hotfix/removed_files ]
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

			write "        \"file\": \"${file}\""
		done < "${BUILD_DIR}"/hotfix/removed_files

		writeln ""
	fi

	writeln "    ]"

	writeln "}"
}

function create_hotfix {
	rm -fr "${BUILD_DIR}"/hotfix
	mkdir -p "${BUILD_DIR}"/hotfix

	echo "Comparing ${BUNDLES_DIR} and ${UPDATE_DIR}"

	echo "Full diff:"

	diff -rq "${BUNDLES_DIR}" "${UPDATE_DIR}" | grep -v /work/Catalina

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

function in_scope {
	if (echo "${1}" | grep -q "^osgi/") || (echo "${1}" | grep -q "^tomcat-.*/webapps/ROOT/")
	then
		return 0
	else
		return 1
	fi
}

function manage_jar {
	if (compare_jars "${1}")
	then
		echo "Changed .jar file: ${1}"

		add_file "${1}"
	fi
}

function package {
	lcd "${BUILD_DIR}"/hotfix

	rm -f ../liferay-hotfix-"${NARWHAL_BUILD_ID}".zip checksums removed_files

	zip -r ../liferay-hotfix-"${NARWHAL_BUILD_ID}".zip ./*

	lcd "${BUILD_DIR}"

	rm -fr hotfix
}

function prepare_update_dir {
	UPDATE_DIR=/opt/liferay/updates/"${DXP_VERSION}"

	local update7z

	if [ -e /opt/liferay/test_update ]
	then
		lcd /opt/liferay/test_update

		local update_file=$(ls | head -n 1)
		UPDATE_DIR=/opt/liferay/updates/"${update_file%%.7z}"

		update7z=/opt/liferay/test_update/"${update_file}"
	else
		echo "Update is not available, download is not yet an option."

		return 1
	fi

	if [ -e ${UPDATE_DIR} ]
	then
		echo "${UPDATE_DIR} is already available."

		return ${SKIPPED}
	fi

	mkdir -p "${UPDATE_DIR}"

	lcd "${UPDATE_DIR}"

	7z x "${update7z}"

	mv liferay-dxp-tomcat/* .
	mv liferay-dxp-tomcat/.* .

	rm -fr liferay-dxp-tomcat/
}

function transform_file_name {
	local file_name=$(echo "${1}" | sed -e s#osgi/modules#MODULES_BASE_PATH#)

	file_name=$(echo "${file_name}" | sed -e s#tomcat.*/webapps/ROOT#WAR_PATH#)

	echo "${file_name}"
}
