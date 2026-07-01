#!/bin/bash

source ../_release_common.sh
source ./_product.sh

function copy_file {
	local dir=$(dirname "${1}" | sed --expression "s#[./]*[^/]*/##")

	if [ "${dir}" == "temp_dir_manage_bom_jar" ]
	then
		dir=""
	fi

	mkdir --parents "${2}/${dir}"

	lc_log DEBUG "Copying ${1}."

	cp --archive "${1}" "${2}/${dir}"
}

function generate_api_jars {
	mkdir --parents "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	mkdir --parents api-jar api-sources-jar

	local enforce_version_artifacts=$(lc_get_property "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/source-formatter.properties" source.check.GradleDependencyArtifactsCheck.enforceVersionArtifacts | sed --expression "s/,/\\n/g")

	#
	# TODO Remove if block when 2023.q3 support is dropped
	#

	if [ -z "${enforce_version_artifacts}" ]
	then
		local enforce_version_artifacts=$(lc_get_property "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/source-formatter.properties" source.check.GradleDependencyArtifactsCheck.enforceVersionArtifacts | sed --expression "s/,/\\n/g")
	fi

	if [ -z "${enforce_version_artifacts}" ]
	then
		lc_log ERROR "Unable to load the version artifacts from source-formatter.properties."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	for artifact in ${enforce_version_artifacts}
	do
		if (! echo "${artifact}" | grep --quiet "com.fasterxml") &&
			(! echo "${artifact}" | grep --quiet "com.liferay.alloy-taglibs:alloy-taglib:") &&
			(! echo "${artifact}" | grep --quiet "com.liferay.portletmvc4spring:com.liferay.portletmvc4spring.test:") &&
			(! echo "${artifact}" | grep --quiet "com.liferay:biz.aQute.bnd.annotation:") &&
			(! echo "${artifact}" | grep --quiet "io.swagger") &&
			(! echo "${artifact}" | grep --quiet "jakarta") &&
			(! echo "${artifact}" | grep --quiet "javax") &&
			(! echo "${artifact}" | grep --quiet "org.jsoup") &&
			(! echo "${artifact}" | grep --quiet "org.osgi")
		then
			continue
		fi

		local group_path=$(echo "${artifact%%:*}" | sed --expression "s#[.]#/#g")

		if [ "${group_path}" == "com/fasterxml/jackson-dataformat" ]
		then
			group_path="com/fasterxml/jackson/dataformat"
		fi

		local name=$(echo "${artifact}" | sed --expression "s/.*:\(.*\):.*/\\1/")
		local version=${artifact##*:}

		if (! echo "${artifact}" | grep --quiet "com.liferay.alloy-taglibs:alloy-taglib:")
		then
			lc_log INFO "Downloading and unzipping https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}-sources.jar."

			lc_download "https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}-sources.jar" "${name}-${version}-sources.jar"

			unzip -d api-sources-jar -o -q "${name}-${version}-sources.jar"

			rm --force "${name}-${version}-sources.jar"
		fi

		lc_log INFO "Downloading and unzipping https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}.jar."

		lc_download "https://repository-cdn.liferay.com/nexus/content/groups/public/${group_path}/${name}/${version}/${name}-${version}.jar" "${name}-${version}.jar"

		manage_bom_jar "${name}-${version}.jar"

		rm --force "${name}-${version}.jar"
	done

	if is_7_3_release
	then
		for portal_jar in portal-kernel support-tomcat
		do
			manage_bom_jar "${_BUNDLES_DIR}/tomcat/lib/ext/${portal_jar}.jar"
		done

		for portal_jar in portal-impl util-bridges util-java util-slf4j util-taglib
		do
			manage_bom_jar "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/lib/${portal_jar}.jar"
		done

		find "${_BUNDLES_DIR}/osgi" "${_BUNDLES_DIR}/tomcat/lib/ext" "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/lib" -name "com.liferay.*.jar" -type f -print0 | while IFS= read -r -d '' module_jar
		do
			manage_bom_jar "${module_jar}"
		done

		for artifact in "commons*.jar" "org.apache.commons.*.jar" "poi*.jar" "spring*.jar"
		do
			find "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/lib" -name "${artifact}" -type f -print0 | while IFS= read -r -d '' module_jar
			do
				local module_jar_basename=$(basename "${module_jar}")

				if (grep $(echo "${module_jar_basename%.jar}:") "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/lib/development/dependencies.properties" || grep $(echo "${module_jar_basename%.jar}:") "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/lib/portal/dependencies.properties")
				then
					manage_bom_jar "${module_jar}"
				fi
			done
		done
	else
		for portal_jar in jaxb-api portal-impl portal-kernel support-tomcat util-bridges util-java util-slf4j util-taglib
		do
			manage_bom_jar "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/${portal_jar}.jar"
		done

		local license_dir="${_BUILD_DIR}/boms/api-jar/com/liferay/portal/ee/license"

		if [ -d "${license_dir}" ]
		then
			rm --force --recursive "${license_dir}"
		fi

		find "${_BUNDLES_DIR}/osgi" "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib" \( -name "com.liferay.*.jar" -o -name "jakarta*.jar" -o -name "javax*.jar" \) -type f -print0 | while IFS= read -r -d '' module_jar
		do
			manage_bom_jar "${module_jar}"
		done
	fi

	if (is_quarterly_release && [ "$(get_release_version)" == "2025.q3.0" ]) ||
	   (is_quarterly_release && is_later_product_version_than "2025.q3.0") ||
	   (is_u_release && is_later_product_version_than "7.4.13-u135")
	then
		lc_download "https://repository-cdn.liferay.com/nexus/service/local/repo_groups/public/content/jakarta/servlet/jakarta.servlet-api/6.0.0/jakarta.servlet-api-6.0.0.jar" "jakarta.servlet-api.jar"

		manage_bom_jar "${_BUNDLES_DIR}/tomcat/lib/servlet-api.jar"
		manage_bom_jar "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF/shielded-container-lib/com.liferay.jakarta.portlet-api.jar"
		manage_bom_jar "jakarta.servlet-api.jar"
	fi

	for file in $(ls api-jar/META-INF --almost-all | grep --extended-regexp --invert-match '^(alloy-util.tld|alloy.tld|c.tld|liferay.tld)$')
	do
		if [[ "${file}" == *.tld ]]
		then
			rm "api-jar/META-INF/${file}"
		fi
	done

	copy_tld "api-jar/META-INF" "liferay-*.tld" "ratings.tld"

	mkdir --parents api-jar/META-INF/resources

	copy_tld "api-jar/META-INF/resources" "liferay-application-list.tld" "liferay-data-engine.tld" "liferay-ddm.tld" "liferay-export-import-changeset.tld" "liferay-form.tld" "liferay-staging.tld" "liferay-template.tld"  "react.tld" "soy.tld"

	mkdir api-jar/META-INF/resources/WEB-INF

	copy_tld "api-jar/META-INF/resources/WEB-INF" "liferay-*.tld" "ratings.tld" "react.tld" "soy.tld"
}

function generate_api_source_jar {
	lc_cd "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}"

	_copy_source_package ./portal-kernel/src/com/liferay

	find . -name taglib -type d -print0 | while IFS= read -r -d '' taglib_dir
	do
		if (! echo "${taglib_dir}" | grep --quiet "/com/liferay/") ||
		   (echo "${taglib_dir}" | grep --quiet "/classes/")
		then
			continue
		fi

		lc_log DEBUG "Copying ${taglib_dir} because it is a taglib."

		_copy_source_package "${taglib_dir}"
	done

	find . -name packageinfo -type f -print0 | while IFS= read -r -d '' packageinfo_file
	do
		if (echo "${packageinfo_file}" | grep --quiet "/classes/") ||
		   (echo "${packageinfo_file}" | grep --quiet "/portal-kernel/")
		then
			continue
		fi

		packageinfo_file=$(echo "${packageinfo_file}" | sed --expression "s#/resources/#/java/#")

		local package_dir=$(dirname "${packageinfo_file}")

		if [ ! -d "${package_dir}" ]
		then
			continue
		fi

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

	start_tomcat

	if [[ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	lc_cd "${_BUILD_DIR}/boms"

	local osgi_version=$(echo "${_PRODUCT_VERSION}" | sed 's/-/\./g')

	if is_quarterly_release
	then
		if is_lts_release
		then
			osgi_version=$(echo "${osgi_version}" | sed "s/.lts//g")
		fi

		osgi_version=$(echo "${osgi_version}" | sed "s/q//g")
	fi

	java -jar biz.aQute.bnd-6.4.0.jar remote distro -o "release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.jar" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro" "${osgi_version}"

	rm --force biz.aQute.bnd-6.4.0.jar
	rm --force "${_BUNDLES_DIR}/osgi/modules/biz.aQute.remote.agent-6.4.0.jar"

	stop_tomcat

	if [[ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function generate_pom_release_api {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.api.pom.tpl" > /dev/null
}

function generate_pom_release_bom {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		--expression "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.pom.tpl" > /dev/null

	echo "" >> "${pom_file_name}"

	find "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng" -name '*.properties' -print0 | \
		xargs -0 awk -F= '/^artifact.url=/  { print $2 }' \
		> /tmp/artifact_urls.txt

	for artifact_file in $(
		find "${_BUNDLES_DIR}/osgi" "${_BUNDLES_DIR}/tomcat/lib/ext" "${_BUNDLES_DIR}/tomcat/webapps/ROOT/WEB-INF" -name '*.jar' | \
			grep --extended-regexp --invert-match "(/osgi/state/)" | \
			sed \
				--expression 's/\.jar$//' \
				--expression "s@.*/@@" \
				--expression "s@-@.@g" | \
			grep --extended-regexp --invert-match "(\.demo|\.sample\.|\.templates\.)" | \
			sort
	)
	do
		grep --extended-regexp "/(com\.liferay\.|)${artifact_file}/" /tmp/artifact_urls.txt | sort | while IFS= read -r artifact_url
		do
			local file_name="${artifact_url##*/}"

			local artifact_id=$(echo "${file_name}" | cut --delimiter='-' --fields=1)
			local version=$(echo "${file_name}" | sed --expression "s@\.\(jar\|war\)\$@@" --expression "s@.*${artifact_file}-@@")

			if [[ "${artifact_url}" == */com/liferay/portal/* ]]
			then
				group_id="com.liferay.portal"
			elif [[ "${artifact_url}" == */com/liferay/commerce/* ]]
			then
				group_id="com.liferay.commerce"
			else
				group_id="com.liferay"
			fi

			if (grep --quiet "(\t)*<groupId>${group_id}</groupId>\n(\t)*<artifactId>${artifact_id}</artifactId>\n\(\t)*<version>${version}</version>" "${pom_file_name}")
			then
				continue
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
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		--expression "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		--expression "s/__RELEASE_API_DEPENDENCY__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.api/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.compile.only.pom.tpl" > /dev/null

	echo  "" >> "${pom_file_name}"

	cut --delimiter='=' --fields=2 "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/releng-pom-compile-only-dependencies.properties" | \
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

function generate_pom_release_bom_jakarta_upgrade {
	if ! has_jakarta_upgrade_bom_support
	then
		lc_log INFO "The Jakarta upgrade BOM should be generated only for quarterly releases starting with 2026.q2.0 and internal releases starting with 7.4.13-u149."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.jakarta.upgrade-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.jakarta.upgrade/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		--expression "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.jakarta.upgrade.pom.tpl" > /dev/null

	echo "" >> "${pom_file_name}"

	local dependencies=(
		"com.fasterxml.jackson.jakarta.rs:jackson-jakarta-rs-base"
		"com.fasterxml.jackson.jakarta.rs:jackson-jakarta-rs-json-provider"
		"com.fasterxml.jackson.jakarta.rs:jackson-jakarta-rs-xml-provider"
		"com.fasterxml.jackson.module:jackson-module-jakarta-xmlbind-annotations"
		"com.liferay:com.graphql.java.dataloader:com-graphql-java-dataloader"
		"com.liferay:com.graphql.java.extended.scalars:com-graphql-java-extended-scalars"
		"com.liferay:com.graphql.java.kickstart:com-graphql-java-kickstart"
		"com.liferay:com.graphql.java.servlet:com-graphql-java-servlet"
		"com.liferay:com.graphql.java:com-graphql-java"
		"com.liferay:com.liferay.alloy.taglib"
		"com.liferay:com.liferay.faces.bridge.api:com-liferay-faces-bridge-api"
		"com.liferay:com.liferay.faces.bridge.ext:com-liferay-faces-bridge-ext"
		"com.liferay:com.liferay.faces.bridge.impl:com-liferay-faces-bridge-impl"
		"com.liferay:com.liferay.faces.util:com-liferay-faces-util"
		"com.liferay:com.sun.xml.bind.jaxb.osgi:com-sun-xml-bind-jaxb-osgi"
		"com.liferay:com.twilio.sdk.twilio:com-twilio-sdk-twilio"
		"com.liferay:jakarta.enterprise.cdi-el:jakarta-enterprise-cdi-el"
		"com.liferay:jakarta.enterprise.cdi:jakarta-enterprise-cdi"
		"com.liferay:jakarta.faces:jakarta-faces-2.3.21"
		"com.liferay:javax.ccpp.ri:javax-ccpp-ri"
		"com.liferay:javax.ccpp:javax-ccpp"
		"com.liferay:net.authorize.anet.java.sdk:net-authorize-anet-java-sdk"
		"com.liferay:net.shibboleth.utilities.java.support:net-shibboleth-utilities-java-support"
		"com.liferay:nl.captcha.simplecaptcha:nl-captcha-simplecaptcha"
		"com.liferay:org.apache.activemq.client:org-apache-activemq-client"
		"com.liferay:org.apache.aries.cdi.extender:org-apache-aries-cdi-extender"
		"com.liferay:org.apache.aries.cdi.extension.el.jsp:org-apache-aries-cdi-extension-el-jsp"
		"com.liferay:org.apache.aries.cdi.extension.http:org-apache-aries-cdi-extension-http"
		"com.liferay:org.apache.aries.cdi.extension.spi:org-apache-aries-cdi-extension-spi"
		"com.liferay:org.apache.aries.cdi.extra:org-apache-aries-cdi-extra"
		"com.liferay:org.apache.aries.cdi.spi:org-apache-aries-cdi-spi"
		"com.liferay:org.apache.aries.cdi.weld:org-apache-aries-cdi-weld"
		"com.liferay:org.apache.aries.jax.rs.whiteboard:org-apache-aries-jax-rs-whiteboard"
		"com.liferay:org.apache.axis2.adb.codegen:org-apache-axis2-adb-codegen"
		"com.liferay:org.apache.axis2.adb:org-apache-axis2-adb"
		"com.liferay:org.apache.axis2.jaxws:org-apache-axis2-jaxws"
		"com.liferay:org.apache.axis2.kernel:org-apache-axis2-kernel"
		"com.liferay:org.apache.axis2.saaj:org-apache-axis2-saaj"
		"com.liferay:org.apache.axis2.transport.http:org-apache-axis2-transport-http"
		"com.liferay:org.apache.chemistry.opencmis.client.bindings:org-apache-chemistry-opencmis-client-bindings"
		"com.liferay:org.apache.chemistry.opencmis.commons.api:org-apache-chemistry-opencmis-commons-api"
		"com.liferay:org.apache.chemistry.opencmis.commons.impl:org-apache-chemistry-opencmis-commons-impl"
		"com.liferay:org.apache.commons.fileupload:org-apache-commons-fileupload"
		"com.liferay:org.apache.cxf.core:org-apache-cxf-core"
		"com.liferay:org.apache.cxf.rt.bindings.soap:org-apache-cxf-rt-bindings-soap"
		"com.liferay:org.apache.cxf.rt.bindings.xml:org-apache-cxf-rt-bindings-xml"
		"com.liferay:org.apache.cxf.rt.databinding.jaxb:org-apache-cxf-rt-databinding-jaxb"
		"com.liferay:org.apache.cxf.rt.frontend.jaxrs:org-apache-cxf-rt-frontend-jaxrs"
		"com.liferay:org.apache.cxf.rt.frontend.jaxws:org-apache-cxf-rt-frontend-jaxws"
		"com.liferay:org.apache.cxf.rt.frontend.simple:org-apache-cxf-rt-frontend-simple"
		"com.liferay:org.apache.cxf.rt.rs.client:org-apache-cxf-rt-rs-client"
		"com.liferay:org.apache.cxf.rt.rs.extension.providers:org-apache-cxf-rt-rs-extension-providers"
		"com.liferay:org.apache.cxf.rt.rs.json.basic:org-apache-cxf-rt-rs-json-basic"
		"com.liferay:org.apache.cxf.rt.rs.security.jose.jaxrs:org-apache-cxf-rt-rs-security-jose-jaxrs"
		"com.liferay:org.apache.cxf.rt.rs.security.jose:org-apache-cxf-rt-rs-security-jose"
		"com.liferay:org.apache.cxf.rt.rs.security.oauth2:org-apache-cxf-rt-rs-security-oauth2-3.2.14"
		"com.liferay:org.apache.cxf.rt.rs.sse:org-apache-cxf-rt-rs-sse"
		"com.liferay:org.apache.cxf.rt.security:org-apache-cxf-rt-security"
		"com.liferay:org.apache.cxf.rt.transports.http:org-apache-cxf-rt-transports-http"
		"com.liferay:org.apache.cxf.rt.ws.addr:org-apache-cxf-rt-ws-addr"
		"com.liferay:org.apache.cxf.rt.ws.policy:org-apache-cxf-rt-ws-policy"
		"com.liferay:org.apache.cxf.rt.wsdl:org-apache-cxf-rt-wsdl"
		"com.liferay:org.apache.cxf.tools.common:org-apache-cxf-tools-common"
		"com.liferay:org.apache.cxf.tools.validator:org-apache-cxf-tools-validator"
		"com.liferay:org.apache.geronimo.specs.jms:org-apache-geronimo-specs-jms"
		"com.liferay:org.apache.ws.commons.axiom.api:org-apache-ws-commons-axiom-api"
		"com.liferay:org.apache.ws.commons.axiom.impl:org-apache-ws-commons-axiom-impl"
		"com.liferay:org.drools.compiler:org-drools-compiler"
		"com.liferay:org.drools.core:org-drools-core"
		"com.liferay:org.drools.knowledge:org-drools-knowledge"
		"com.liferay:org.eclipse.equinox.http.servlet:org-eclipse-equinox-http-servlet"
		"com.liferay:org.hdrhistogram:org-hdrhistogram"
		"com.liferay:org.hibernate.validator:org-hibernate-validator"
		"com.liferay:org.jfree.jfreechart:org-jfree-jfreechart"
		"com.liferay:org.opensaml.impl:org-opensaml-impl"
		"com.liferay:org.opensaml.messaging.impl:org-opensaml-messaging-impl"
		"com.liferay:org.opensaml.messaging:org-opensaml-messaging"
		"com.liferay:org.osgi.service.cdi:org-osgi-service-cdi"
		"com.liferay:org.osgi.service.http.whiteboard:org-osgi-service-http-whiteboard"
		"com.liferay:org.osgi.service.http:org-osgi-service-http"
		"com.liferay:org.osgi.service.jaxrs:org-osgi-service-jaxrs"
		"com.liferay:org.quartz:org-quartz"
		"com.liferay:org.scribe:org-scribe"
		"com.liferay:org.springframework.test:org-springframework-test"
		"com.liferay:org.springframework.web:org-springframework-web"
		"io.swagger.core.v3:swagger-annotations-jakarta"
		"io.swagger.core.v3:swagger-core-jakarta"
		"io.swagger.core.v3:swagger-integration-jakarta"
		"io.swagger.core.v3:swagger-jaxrs2-jakarta"
		"io.swagger.core.v3:swagger-models-jakarta"
		"jakarta.annotation:jakarta.annotation-api"
		"jakarta.el:jakarta.el-api"
		"jakarta.faces:jakarta.faces-api"
		"jakarta.interceptor:jakarta.interceptor-api"
		"jakarta.mvc:jakarta.mvc-api"
		"jakarta.servlet.jsp:jakarta.servlet.jsp-api"
		"jakarta.servlet:jakarta.servlet-api"
		"jakarta.validation:jakarta.validation-api"
		"jakarta.websocket:jakarta.websocket-api"
		"jakarta.websocket:jakarta.websocket-client-api"
		"org.apache.felix:org.apache.felix.cm.json"
		"org.apache.ws.xmlschema:xmlschema-core"
		"org.jboss.classfilewriter:jboss-classfilewriter"
		"org.jboss.logging:jboss-logging"
		"org.jboss.weld:weld-osgi-bundle"
		"org.mitre.dsmiley.httpproxy:smiley-http-proxy-servlet"
	)

	for dependency in "${dependencies[@]}"
	do
		local artifact_id=$(echo "${dependency}" | cut --delimiter=':' --fields=2)
		local group_id=$(echo "${dependency}" | cut --delimiter=':' --fields=1)
		local releng_dir_name=$(echo "${dependency}" | cut --delimiter=':' --fields=3)
		local version=""

		if [ -n "${releng_dir_name}" ]
		then
			local artifact_properties_file="${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/third-party/${releng_dir_name}/artifact.properties"

			if [ -f "${artifact_properties_file}" ]
			then
				local artifact_url=$(lc_get_property "${artifact_properties_file}" artifact.url)

				version=$(basename "${artifact_url}" | sed --expression "s/\.jar$//" --expression "s/^${artifact_id}-//")
			fi
		else
			version=$( \
				grep --only-matching \
					"[=|]${group_id}:${artifact_id}:[^|]*" \
					"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/util/source-formatter/src/main/resources/dependencies/jakarta-transform-dependencies.txt" | \
				head --lines=1 | \
				cut --delimiter=':' --fields=3)
		fi

		if [ -z "${version}" ]
		then
			lc_log ERROR "Unable to resolve the version of ${group_id}:${artifact_id}."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		(
			echo -e "\t\t\t<dependency>"
			echo -e "\t\t\t\t<groupId>${group_id}</groupId>"
			echo -e "\t\t\t\t<artifactId>${artifact_id}</artifactId>"
			echo -e "\t\t\t\t<version>${version}</version>"
			echo -e "\t\t\t</dependency>"
		) >> "${pom_file_name}"
	done

	(
		echo -e "\t\t</dependencies>"
		echo -e "\t</dependencyManagement>"
		echo "</project>"
	) >> "${pom_file_name}"
}

function generate_pom_release_bom_test {
	if ! is_quarterly_release
	then
		lc_log INFO "The test BOM should be generated only for quarterly releases."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.test-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.test/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		--expression "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.test.pom.tpl" > /dev/null

	echo "" >> "${pom_file_name}"

	local dependencies=(
		biz.aQute.bnd:biz.aQute.bnd:3.5.0
		biz.aQute.bnd:biz.aQute.bndlib:3.5.0
		com.liferay.portal:com.liferay.portal.test
		com.liferay.portal:com.liferay.portal.test.integration:6.0.36
		com.liferay:com.liferay.arquillian.extension.junit.bridge
		com.liferay:com.liferay.arquillian.extension.junit.bridge.connector
		com.liferay:org.apache.logging.log4j
		com.liferay:org.apache.logging.log4j.core
		junit:junit:4.13.1
		org.apache.aries.jmx:org.apache.aries.jmx.core:1.1.8
		org.slf4j:log4j-over-slf4j:1.7.25
	)

	local sorted_dependencies=($(printf "%s\n" "${dependencies[@]}" | sort --field-separator=':' --key=2,2))

	local artifact_urls=""

	for file in \
		"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/portal-test.properties" \
		"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/test/arquillian-extension-junit-bridge-connector/artifact.properties" \
		"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/test/arquillian-extension-junit-bridge/artifact.properties" \
		"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/third-party/biz-aQute-bndlib/artifact.properties" \
		"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/third-party/org-apache-logging-log4j-core/artifact.properties" \
		"${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/modules/.releng/third-party/org-apache-logging-log4j/artifact.properties"
	do
		artifact_urls+=$(awk -F= '/^artifact.url=/ { print $2 }' "$file")
		artifact_urls+=$'\n'
	done

	for dependency in "${sorted_dependencies[@]}"
	do
		local artifact_id=$(echo "${dependency}" | cut --delimiter=':' --fields=2)
		local group_id=$(echo "${dependency}" | cut --delimiter=':' --fields=1)
		local version=$(echo "${dependency}" | cut --delimiter=':' --fields=3)

		if [ -z "${version}" ]
		then
			local artifact_url=$(echo "${artifact_urls}" | grep "/${artifact_id}-")

			version=$( \
				basename "${artifact_url}" | \
				sed --expression 's/\.jar$//' | \
				cut --delimiter='-' --fields=2-)
		fi

		(
			echo -e "\t\t\t<dependency>"
			echo -e "\t\t\t\t<groupId>${group_id}</groupId>"
			echo -e "\t\t\t\t<artifactId>${artifact_id}</artifactId>"
			echo -e "\t\t\t\t<version>${version}</version>"
			echo -e "\t\t\t</dependency>"
		) >> "${pom_file_name}"
	done

	(
		echo -e "\t\t</dependencies>"
		echo -e "\t</dependencyManagement>"
		echo "</project>"
	) >> "${pom_file_name}"
}

function generate_pom_release_bom_third_party {
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "s/__GITHUB_REPOSITORY__/liferay-${LIFERAY_RELEASE_PRODUCT_NAME}/" \
		--expression "s/__PRODUCT_VERSION__/${_PRODUCT_VERSION}/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.bom.third.party.pom.tpl" > /dev/null

	echo "" >> "${pom_file_name}"

	local included_dependencies=()
	local pom_compile_only_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only-${_ARTIFACT_RC_VERSION}.pom"

	local dependencies_properties

	IFS=$'\n' read -d '' -ra dependencies_properties < "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/lib/development/dependencies.properties"

	local portal_dependencies_properties

	IFS=$'\n' read -d '' -ra portal_dependencies_properties < "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}/lib/portal/dependencies.properties"

	dependencies_properties+=("${portal_dependencies_properties[@]}")

	for dependency_property in "${dependencies_properties[@]}"
	do
		IFS=':' read -ra dependency_property_parts <<< "$(echo "${dependency_property}" | cut --delimiter='=' --fields=2)"

		if [[ ${included_dependencies[@]} =~ "${dependency_property_parts[0]}${dependency_property_parts[1]}${dependency_property_parts[2]}" ]]
		then
			continue
		fi

		included_dependencies+=("${dependency_property_parts[0]}${dependency_property_parts[1]}${dependency_property_parts[2]}")

		if (grep --quiet "<artifactId>${dependency_property_parts[1]}</artifactId>" "${pom_compile_only_file_name}" && grep --quiet "<groupId>${dependency_property_parts[0]}</groupId>" "${pom_compile_only_file_name}")
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
	local pom_file_name="release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.pom"

	lc_log DEBUG "Generating ${pom_file_name}."

	sed \
		--expression "s/__ARTIFACT_ID__/release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro/" \
		--expression "s/__ARTIFACT_RC_VERSION__/${_ARTIFACT_RC_VERSION}/" \
		--expression "w ${pom_file_name}" \
		"${_RELEASE_TOOL_DIR}/templates/release.distro.pom.tpl" > /dev/null
}

function generate_poms {
	mkdir --parents "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	rm --force ./*.pom

	lc_time_run generate_pom_release_api
	lc_time_run generate_pom_release_bom
	lc_time_run generate_pom_release_bom_compile_only
	lc_time_run generate_pom_release_bom_jakarta_upgrade
	lc_time_run generate_pom_release_bom_test
	lc_time_run generate_pom_release_bom_third_party
	lc_time_run generate_pom_release_distro
}

function _copy_source_package {

	#
	# TODO Exclude what is not packaged
	#

	local new_dir_name=$(echo "${1}" | sed --expression "s#.*/com/liferay/#com/liferay/#")

	new_dir_name="${_BUILD_DIR}"/boms/api-sources-jar/$(dirname "${new_dir_name}")

	mkdir --parents "${new_dir_name}"

	cp --archive "${1}" "${new_dir_name}"
}

function copy_tld {
	local arguments=""

	local tlds=("${@:2}")

	for tld in "${tlds[@]}"
	do
		if [ -n "${arguments}" ]
		then
			arguments+=" -o "
		fi

		arguments+="-name \"${tld}\""
	done

	for file in $(eval find "${_PROJECTS_DIR}/${LIFERAY_PORTAL_REPOSITORY_NAME}" \
		"${arguments}" -type f | \
			grep \
				--extended-regexp "(/build/|/classes/|/gradleTest/|/sdk/|/test/|/testIntegration/)" \
				--invert-match | \
			awk -F "/" '{print $NF, $0}' | \
			sort --key 1,1 --unique | \
			awk '{print $2}')
	do
		lc_log INFO "Copying file ${file} to ${1}."

		cp "${file}" "${1}"
	done
}

function manage_bom_jar {
	lc_log DEBUG "Processing ${1} for api jar."

	mkdir --parents temp_dir_manage_bom_jar

	unzip -d temp_dir_manage_bom_jar -o -q "${1}"

	#rm --force "${name}-${version}.jar"

	if (basename "${1}" | grep --extended-regexp --quiet "^com.liferay.") &&
	   (! basename "${1}" | grep --quiet "com.liferay.jakarta.portlet-api.jar")
	then
		local current_file

		find temp_dir_manage_bom_jar -name "*.jar" -type f -print0 | while IFS= read -r -d '' current_file
		do
			lc_log DEBUG "Removing ${current_file}."

			rm --force "${current_file}"
		done

		find temp_dir_manage_bom_jar -name "java-docs-*.xml" -type f -print0 | while IFS= read -r -d '' current_file
		do
			lc_log DEBUG "Removing ${current_file}."

			rm --force "${current_file}"
		done

		find temp_dir_manage_bom_jar -name "node-modules" -type d -print0 | while IFS= read -r -d '' current_file
		do
			lc_log DEBUG "Removing ${current_file}."

			rm --force "${current_file}"
		done

		find temp_dir_manage_bom_jar -maxdepth 1 -type f -print0 | while IFS= read -r -d '' current_file
		do
			copy_file "${current_file}" api-jar
		done

		find temp_dir_manage_bom_jar -name kernel -type d -print0 | while IFS= read -r -d '' current_file
		do
			if (echo "${current_file}" | grep "com/liferay/portal/kernel")
			then
				copy_file "${current_file}" api-jar
			fi
		done

		find temp_dir_manage_bom_jar -name taglib -type d -print0 | while IFS= read -r -d '' current_file
		do
			if (echo "${current_file}" | grep "com/liferay")
			then
				copy_file "${current_file}" api-jar
			fi
		done

		find temp_dir_manage_bom_jar -name packageinfo -type f -print0 | while IFS= read -r -d '' current_file
		do
			copy_file "$(dirname "${current_file}")" api-jar
		done
	else
		rm --force --recursive temp_dir_manage_bom_jar/META-INF/custom-sql
		rm --force --recursive temp_dir_manage_bom_jar/META-INF/images
		rm --force --recursive temp_dir_manage_bom_jar/META-INF/sql
		rm --force --recursive temp_dir_manage_bom_jar/META-INF/versions

		if [[ "${1}" == javax.persistence-*.jar ]]
		then
			rm --force temp_dir_manage_bom_jar/META-INF/ECLIPSE_.RSA
			rm --force temp_dir_manage_bom_jar/META-INF/ECLIPSE_.SF
		fi

		cp --archive temp_dir_manage_bom_jar/* api-jar
	fi

	rm --force --recursive temp_dir_manage_bom_jar
}