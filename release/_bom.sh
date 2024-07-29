#!/bin/bash

function generate_api_jars {
	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	mkdir -p api-jar api-sources-jar

	local enforce_version_artifacts=$(lc_get_property "${_PROJECTS_DIR}/liferay-portal-ee/source-formatter.properties" source.check.GradleDependencyArtifactsCheck.enforceVersionArtifacts | sed -e "s/,/\\n/g")

	#
	# TODO Remove if block when 2023.q3 support is dropped
	#

	if [ -z "${enforce_version_artifacts}" ]
	then
		local enforce_version_artifacts=$(lc_get_property "${_PROJECTS_DIR}/liferay-portal-ee/modules/source-formatter.properties" source.check.GradleDependencyArtifactsCheck.enforceVersionArtifacts | sed -e "s/,/\\n/g")
	fi

	if [ -z "${enforce_version_artifacts}" ]
	then
		lc_log ERROR "Unable to load the version artifacts from source-formatter.properties."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	for artifact in ${enforce_version_artifacts}
	do
		if (! echo "${artifact}" | grep -q "com.fasterxml") &&
			(! echo "${artifact}" | grep -q "com.liferay.alloy-taglibs:alloy-taglib:") &&
			(! echo "${artifact}" | grep -q "com.liferay.alloy-taglibs:alloy-taglib:") &&
			(! echo "${artifact}" | grep -q "com.liferay.portletmvc4spring:com.liferay.portletmvc4spring.test:") &&
			(! echo "${artifact}" | grep -q "com.liferay:biz.aQute.bnd.annotation:") &&
			(! echo "${artifact}" | grep -q "io.swagger") &&
			(! echo "${artifact}" | grep -q "javax") &&
			(! echo "${artifact}" | grep -q "org.jsoup") &&
			(! echo "${artifact}" | grep -q "org.osgi")
		then
			continue
		fi

		local group_path=$(echo "${artifact%%:*}" | sed -e "s#[.]#/#g")

		if [ "${group_path}" == "com/fasterxml/jackson-dataformat" ]
		then
			group_path="com/fasterxml/jackson/dataformat"
		fi

		local name=$(echo "${artifact}" | sed -e "s/.*:\(.*\):.*/\\1/")
		local version=${artifact##*:}

		lc_log INFO "Downloading and unzipping https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}-sources.jar."

		lc_download "https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}-sources.jar" "${name}-${version}-sources.jar"

		unzip -d api-sources-jar -o -q "${name}-${version}-sources.jar"

		rm -f "${name}-${version}-sources.jar"

		lc_log INFO "Downloading and unzipping https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}.jar."

		lc_download "https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}.jar" "${name}-${version}.jar"

		_manage_bom_jar "${name}-${version}.jar"

		rm -f "${name}-${version}.jar"
	done

	for portal_jar in portal-impl portal-kernel support-tomcat util-bridges util-java util-slf4j util-taglib
	do
		_manage_bom_jar "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/${portal_jar}.jar"
	done

	find "${_BUNDLES_DIR}/osgi" "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib" -name "com.liferay.*.jar" -type f -print0 | while IFS= read -r -d '' module_jar
	do
		_manage_bom_jar "${module_jar}"
	done
}

function generate_api_source_jar {
	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	_copy_source_package ./portal-kernel/src/com/liferay

	find . -name taglib -type d -print0 | while IFS= read -r -d '' taglib_dir
	do
		if (! echo "${taglib_dir}" | grep -q "/com/liferay/") ||
		   (echo "${taglib_dir}" | grep -q "/classes/")
		then
			continue
		fi

		lc_log DEBUG "Copying ${taglib_dir} because it is a taglib."

		_copy_source_package "${taglib_dir}"
	done

	find . -name packageinfo -type f -print0 | while IFS= read -r -d '' packageinfo_file
	do
		if (echo "${packageinfo_file}" | grep -q "/classes/") ||
		   (echo "${packageinfo_file}" | grep -q "/portal-kernel/")
		then
			continue
		fi

		packageinfo_file=$(echo "${packageinfo_file}" | sed -e "s#/resources/#/java/#")

		local package_dir=$(dirname "${packageinfo_file}")

		lc_log DEBUG "Copying ${package_dir} because it has a packageinfo."

		_copy_source_package "${package_dir}"
	done
}

function generate_distro_jar {
	if [ ! -e "${_BUNDLES_DIR}/osgi/modules/biz.aQute.remote.agent-6.4.0.jar" ]
	then
		lc_download "https://repo1.maven.org/maven2/biz/aQute/bnd/biz.aQute.remote.agent/6.4.0/biz.aQute.remote.agent-6.4.0.jar" "${_BUNDLES_DIR}/deploy/biz.aQute.remote.agent-6.4.0.jar"
	fi

	lc_download "https://repo1.maven.org/maven2/biz/aQute/bnd/biz.aQute.bnd/6.4.0/biz.aQute.bnd-6.4.0.jar" "${_BUILD_DIR}/boms/biz.aQute.bnd-6.4.0.jar"

	chmod u+x "${_BUILD_DIR}/boms/biz.aQute.bnd-6.4.0.jar"

	lc_cd "${_BUNDLES_DIR}/tomcat/bin"

	./catalina.sh start

	lc_cd "${_BUILD_DIR}/boms"

	local osgi_version=$(echo "${_PRODUCT_VERSION}"| sed 's/-/\./g')

	if [[ $(echo "${_PRODUCT_VERSION}" | grep "q") ]]
	then
		osgi_version=$(echo "${_PRODUCT_VERSION}" | sed 's/q//g')
	fi

	java -jar biz.aQute.bnd-6.4.0.jar remote distro -o release."${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}".jar release."${LIFERAY_RELEASE_PRODUCT_NAME}".distro "${osgi_version}"

	rm -f biz.aQute.bnd-6.4.0.jar

	lc_cd "${_BUNDLES_DIR}/tomcat/bin"

	./catalina.sh stop
}

function generate_pom_release_api {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api/" \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.api.pom.tpl" > /dev/null
}

function generate_pom_release_bom {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom/" \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.pom.tpl" > /dev/null

	echo "" >> "${pom_file_name}"

	find "${_PROJECTS_DIR}/liferay-portal-ee/modules/.releng" -name '*.properties' -print0 | \
		xargs -0 awk -F= '/^artifact.url=/  { print $2 }' \
		> /tmp/artifact_urls.txt

	for artifact_file in $(
		find "${_BUNDLES_DIR}/osgi" "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF" -name '*.jar' | \
			sed \
				-e 's/\.jar$//' \
				-e "s@.*/@@" \
				-e "s@-@.@g" | \
			grep -v -E "(\.demo|\.sample\.|\.templates\.)" | \
			sort
	)
	do
		grep -E "/(com\.liferay\.|)${artifact_file}/" /tmp/artifact_urls.txt | while IFS= read -r artifact_url
		do
			local file_name="${artifact_url##*/}"

			local artifact_id=$(echo "${file_name}" | sed "s@-${version}.*@@")
			local version=$(echo "${file_name}" | sed -e "s@\.jar\$@@" -e "s@.*${artifact_file}-@@")

			if [[ "${artifact_url}" == */com/liferay/portal/* ]]
			then
				group_id="com.liferay.portal"
			elif [[ "${artifact_url}" == */com/liferay/commerce/* ]]
			then
				group_id="com.liferay.commerce"
			else
				group_id="com.liferay"
			fi

			(
				echo -e "\t\t\t<dependency>"
				echo -e "\t\t\t\t<groupId>${group_id}</groupId>"
				echo -e "\t\t\t\t<artifactId>${artifact_id}</artifactId>"
				echo -e "\t\t\t\t<version>${version}</version>"
				echo -e "\t\t\t</dependency>"
			) >> "${pom_file_name}"
		done
	done

	(
		echo -e "\t\t</dependencies>"
		echo -e "\t</dependencyManagement>"
		echo "</project>"
	) >> "${pom_file_name}"
}

function generate_pom_release_bom_compile_only {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only/" \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "s/__RELEASE_API_DEPENDENCY__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.compile.only.pom.tpl" > /dev/null

	echo  "" >> "${pom_file_name}"

	cut -d= -f2 "${_PROJECTS_DIR}/liferay-portal-ee/modules/releng-pom-compile-only-dependencies.properties" | \
		while IFS=: read -r group_id artifact_id version
		do
			echo -e "\t\t\t<dependency>"
			echo -e "\t\t\t\t<groupId>${group_id}</groupId>"
			echo -e "\t\t\t\t<artifactId>${artifact_id}</artifactId>"
			echo -e "\t\t\t\t<version>${version}</version>"
			echo -e "\t\t\t</dependency>"
		done >> "${pom_file_name}"

	(
		echo -e "\t\t</dependencies>"
		echo -e "\t</dependencyManagement>"
		echo -e "</project>"
	) >> "${pom_file_name}"
}

function generate_pom_release_bom_third_party {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party/" \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.third.party.pom.tpl" > /dev/null

	echo "" >> "${pom_file_name}"

	local included_dependencies=()
	local pom_compile_only_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom"

	local dependencies_properties

	IFS=$'\n' read -d '' -ra dependencies_properties < "${_PROJECTS_DIR}/liferay-portal-ee/lib/development/dependencies.properties"

	local portal_dependencies_properties

	IFS=$'\n' read -d '' -ra portal_dependencies_properties < "${_PROJECTS_DIR}/liferay-portal-ee/lib/portal/dependencies.properties"

	dependencies_properties+=("${portal_dependencies_properties[@]}")

	for dependency_property in "${dependencies_properties[@]}"
	do
		IFS=':' read -ra dependency_property_parts <<< "$(echo "${dependency_property}" | cut -d = -f 2)"

		if [[ ${included_dependencies[@]} =~ "${dependency_property_parts[0]}${dependency_property_parts[1]}${dependency_property_parts[2]}" ]]
		then
			continue
		fi

		included_dependencies+=("${dependency_property_parts[0]}${dependency_property_parts[1]}${dependency_property_parts[2]}")

		if (grep -q "<artifactId>${dependency_property_parts[1]}</artifactId>" "${pom_compile_only_file_name}" && grep -q "<groupId>${dependency_property_parts[0]}</groupId>" "${pom_compile_only_file_name}")
		then
			continue
		fi

		(
			echo -e "\t\t\t<dependency>"
			echo -e "\t\t\t\t<groupId>${dependency_property_parts[0]}</groupId>"
			echo -e "\t\t\t\t<artifactId>${dependency_property_parts[1]}</artifactId>"
			echo -e "\t\t\t\t<version>${dependency_property_parts[2]}</version>"
			echo -e "\t\t\t</dependency>"
		) >> "${pom_file_name}"
	done

	(
	    echo -e "\t\t</dependencies>"
	    echo -e "\t</dependencyManagement>"
	    echo "</project>"
	) >> "${pom_file_name}"
}

function generate_pom_release_distro {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro/" \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.distro.pom.tpl" > /dev/null
}

function generate_poms {
	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	rm -f ./*.pom

	lc_time_run generate_pom_release_api
	lc_time_run generate_pom_release_bom
	lc_time_run generate_pom_release_bom_compile_only
	lc_time_run generate_pom_release_bom_third_party
	lc_time_run generate_pom_release_distro
}

function _copy_file {
	local dir=$(dirname "${1}" | sed -e "s#[./]*[^/]*/##")

	mkdir -p "${2}/${dir}"

	lc_log DEBUG "Copying ${1}."

	cp -a "${1}" "${2}/${dir}"
}

function _copy_source_package {

	#
	# TODO Exclude what is not packaged
	#

	local new_dir_name=$(echo "${1}" | sed -e "s#.*/com/liferay/#com/liferay/#")

	new_dir_name="${_BUILD_DIR}"/boms/api-sources-jar/$(dirname "${new_dir_name}")

	mkdir -p "${new_dir_name}"

	cp -a "${1}" "${new_dir_name}"
}

function _manage_bom_jar {
	lc_log DEBUG "Processing ${1} for api jar."

	mkdir -p temp_dir_manage_bom_jar

	unzip -d temp_dir_manage_bom_jar -o -q "${1}"

	#rm -f "${name}-${version}.jar"

	if (basename "${1}" | grep -Eq "^com.liferay.")
	then
		local current_file

		find temp_dir_manage_bom_jar -name "*.jar" -type f -print0 | while IFS= read -r -d '' current_file
		do
			lc_log DEBUG "Removing ${current_file}."

			rm -f "${current_file}"
		done

		find temp_dir_manage_bom_jar -name "java-docs-*.xml" -type f -print0 | while IFS= read -r -d '' current_file
		do
			lc_log DEBUG "Removing ${current_file}."

			rm -f "${current_file}"
		done

		find temp_dir_manage_bom_jar -name "node-modules" -type d -print0 | while IFS= read -r -d '' current_file
		do
			lc_log DEBUG "Removing ${current_file}."

			rm -f "${current_file}"
		done

		find temp_dir_manage_bom_jar -maxdepth 1 -type f -print0 | while IFS= read -r -d '' current_file
		do
			_copy_file "${current_file}" api-jar
		done

		find temp_dir_manage_bom_jar -name kernel -type d -print0 | while IFS= read -r -d '' current_file
		do
			if (echo "${current_file}" | grep "com/liferay/portal/kernel")
			then
				_copy_file "${current_file}" api-jar
			fi
		done

		find temp_dir_manage_bom_jar -name taglib -type d -print0 | while IFS= read -r -d '' current_file
		do
			if (echo "${current_file}" | grep "com/liferay")
			then
				_copy_file "${current_file}" api-jar
			fi
		done

		find temp_dir_manage_bom_jar -name packageinfo -type f -print0 | while IFS= read -r -d '' current_file
		do
			_copy_file "$(dirname "${current_file}")" api-jar
		done
	else
		rm -fr temp_dir_manage_bom_jar/META-INF/custom-sql
		rm -fr temp_dir_manage_bom_jar/META-INF/images
		rm -fr temp_dir_manage_bom_jar/META-INF/sql
		rm -fr temp_dir_manage_bom_jar/META-INF/versions

		cp -a temp_dir_manage_bom_jar/* api-jar
	fi

	rm -fr temp_dir_manage_bom_jar
}