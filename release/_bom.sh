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

function generate_pom_release_dxp_api {
	local pom_file_name="release.dxp.api-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.FROM_SCRATCH.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.dxp.api.pom.tpl" > /dev/null
}

function generate_pom_release_dxp_bom {
	local pom_file_name="release.dxp.bom-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.FROM_SCRATCH.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.dxp.bom.pom.tpl" > /dev/null

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

function generate_pom_release_dxp_bom_compile_only {
	local pom_file_name="release.dxp.bom.compile.only-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.FROM_SCRATCH.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.dxp.bom.compile.only.pom.tpl" > /dev/null

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

function generate_pom_release_dxp_bom_third_party {
	local pom_file_name="release.dxp.bom.third.party-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.FROM_SCRATCH.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		-e "s/__BUILD_TIMESTAMP__/${_BUILD_TIMESTAMP}/" \
		-e "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		-e "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.dxp.bom.third.party.pom.tpl" > /dev/null

	local property_files=(
		"${_PROJECTS_DIR}/liferay-portal-ee/lib/development/dependencies.properties"
		"${_PROJECTS_DIR}/liferay-portal-ee/lib/portal/dependencies.properties"
	)

	find "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib" -name "*.jar" -print0 | \
		while IFS= read -d '' -r jar_file
		do
			if (unzip -l "${jar_file}" | grep -q "pom.xml$")
			then
				local artifact_name="${jar_file##*/}"

				artifact_name="${artifact_name/%\.jar}"

				if [[ "${artifact_name}" == com.liferay.* ]]
				then
					continue
				fi

				artifact_name="${artifact_name##*.}"

				local artifact_properties=$(grep -w "^$artifact_name" "${property_files[@]}")

				if [ -z "${artifact_properties}" ]
				then
					continue
				fi

				if [[ "${artifact_properties}" == *development/dependencies.properties* ]] && [[ "${artifact_properties}" == *portal/dependencies.properties* ]]
				then
					artifact_properties=$(echo "${artifact_properties}" | grep "portal/dependencies.properties" | cut -d= -f2)
				else
					artifact_properties=$(echo "$artifact_properties" | cut -d= -f2)
				fi

				echo "$artifact_properties" | \
					while IFS=: read -r group_id artifact_id version
					do
						echo -e "\t\t\t<dependency>"
						echo -e "\t\t\t\t<groupId>${group_id}</groupId>"
						echo -e "\t\t\t\t<artifactId>${artifact_id}</artifactId>"
						echo -e "\t\t\t\t<version>${version}</version>"
						echo -e "\t\t\t</dependency>"
					done >> "${pom_file_name}"
			fi
		done

		(
			echo -e "\t\t</dependencies>"
			echo -e "\t</dependencyManagement>"
			echo "</project>"
		) >> "${pom_file_name}"
}

function generate_poms {
	if (! echo "${_PRODUCT_VERSION}" | grep -q "q")
	then
		lc_log INFO "BOMs are only generated for quarterly updates."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	if [ "${LIFERAY_RELEASE_PRODUCT_NAME}" == "portal" ]
	then
		lc_log INFO "The product is set to \"portal\" and building BOMs will not be supported until LRP-4752 is completed."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local base_version=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.profile-dxp.properties "release.info.version").u$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.trivial")

	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	rm -f ./*.pom

	for pom in "release.${LIFERAY_RELEASE_PRODUCT_NAME}.api" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party"
	do
		lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/${pom}/${base_version}/${pom}-${base_version}.pom" "${pom}-${base_version}.pom"

		sed \
			-e "s#<version>${base_version}</version>#<version>${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}</version>#" \
			-e "s#<connection>scm:git:git@github.com:liferay/liferay-portal.git</connection>#<connection>scm:git:git@github.com:liferay/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}.git</connection>#" \
			-e "s#<developerConnection>scm:git:git@github.com:liferay/liferay-portal.git</developerConnection>#<developerConnection>scm:git:git@github.com:liferay/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}.git</developerConnection>#" \
			-e "s#<tag>.*</tag>#<tag>${_PRODUCT_VERSION}</tag>#" \
			-e "s#<url>https://github.com/liferay/liferay-portal</url>#<url>https://github.com/liferay/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}</url>#" \
			-e "w ${pom}-${_PRODUCT_VERSION}-${_BUILD_TIMESTAMP}.pom" \
			"${pom}-${base_version}.pom" > /dev/null

		rm -f "${pom}-${base_version}.pom"
	done
}

function generate_poms_from_scratch {
	lc_time_run generate_pom_release_dxp_api
	lc_time_run generate_pom_release_dxp_bom
	lc_time_run generate_pom_release_dxp_bom_compile_only
	lc_time_run generate_pom_release_dxp_bom_third_party
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

	mkdir -p jar-temp

	unzip -d jar-temp -o -q "${1}"

	#rm -f "${name}-${version}.jar"

	if (basename "${1}" | grep -Eq "^com.liferay.")
	then
		find jar-temp -name "*.jar" -type f -print0 | while IFS= read -r -d '' jar_temp_file
		do
			lc_log DEBUG "Removing ${jar_temp_file}."

			rm -f "${jar_temp_file}"
		done

		find jar-temp -name "java-docs-*.xml" -type f -print0 | while IFS= read -r -d '' jar_temp_file
		do
			lc_log DEBUG "Removing ${jar_temp_file}."

			rm -f "${jar_temp_file}"
		done

		find jar-temp -name "node-modules" -type d -print0 | while IFS= read -r -d '' jar_temp_file
		do
			lc_log DEBUG "Removing ${jar_temp_file}."

			rm -f "${jar_temp_file}"
		done

		find jar-temp -maxdepth 1 -type f -print0 | while IFS= read -r -d '' jar_temp_file
		do
			_copy_file "${jar_temp_file}" api-jar
		done

		find jar-temp -name kernel -type d -print0 | while IFS= read -r -d '' jar_temp_file
		do
			if (echo "${jar_temp_file}" | grep "com/liferay/portal/kernel")
			then
				_copy_file "${jar_temp_file}" api-jar
			fi
		done

		find jar-temp -name taglib -type d -print0 | while IFS= read -r -d '' jar_temp_file
		do
			if (echo "${jar_temp_file}" | grep "com/liferay")
			then
				_copy_file "${jar_temp_file}" api-jar
			fi
		done

		find jar-temp -name packageinfo -type f -print0 | while IFS= read -r -d '' jar_temp_file
		do
			_copy_file "$(dirname "${jar_temp_file}")" api-jar
		done
	else
		rm -fr jar-temp/META-INF/custom-sql
		rm -fr jar-temp/META-INF/images
		rm -fr jar-temp/META-INF/sql
		rm -fr jar-temp/META-INF/versions

		cp -a jar-temp/* api-jar
	fi

	rm -fr jar-temp
}