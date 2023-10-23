#!/bin/bash

function generate_bom {
	mkdir -p "${_BUILD_DIR}/boms"
	(
		echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
		echo "<project xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd\" xmlns=\"http://maven.apache.org/POM/4.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">"
		echo "	<modelVersion>4.0.0</modelVersion>"
		echo "	<groupId>com.liferay.portal</groupId>"
		echo "	<artifactId>release.dxp.bom${2}</artifactId>"
		echo "	<version>${_DXP_VERSION}</version>"
		echo "	<packaging>pom</packaging>"
		echo "	<licenses>"
		echo "		<license>"
		echo "			<name>LGPL 2.1</name>"
		echo "			<url>http://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt</url>"
		echo "		</license>"
		echo "	</licenses>"
		echo "	<developers>"
		echo "		<developer>"
		echo "		<name>Brian Wing Shun Chan</name>"
		echo "			<organization>Liferay, Inc.</organization>"
		echo "			<organizationUrl>http://www.liferay.com</organizationUrl>"
		echo "		</developer>"
		echo "	</developers>"
		echo "	<scm>"
		echo "		<connection>scm:git:git@github.com:liferay/liferay-dxp.git</connection>"
		echo "		<developerConnection>scm:git:git@github.com:liferay/liferay-dxp.git</developerConnection>"
		echo "		<tag>${_DXP_VERSION}</tag>"
		echo "		<url>https://github.com/liferay/liferay-dxp</url>"
		echo "	</scm>"
		echo "	<dependencyManagement>"
		echo "		<dependencies>"

		"generate_bom_${1}"

		echo "		</dependencies>"
		echo "	</dependencyManagement>"
		echo "	<repositories>"
		echo "		<repository>"
		echo "			<id>liferay-public-releases</id>"
		echo "			<name>Liferay Public Releases</name>"
		echo "			<url>https://repository-cdn.liferay.com/nexus/content/repositories/liferay-public-releases/</url>"
		echo "		</repository>"
		echo "	</repositories>"
		echo "</project>"
	) > "${_BUILD_DIR}/boms/release.dxp.bom${2}-${_DXP_VERSION}.pom"
}


function generate_bom_compile_only {
	while IFS= read -r line
	do
		local data=${line#*=}
		local artifact_id="${data#*:}"

		artifact_id=${artifact_id%%:*}

		echo "			<dependency>"
		echo "				<groupId>${data%%:*}</groupId>"
		echo "				<artifactId>${artifact_id}</artifactId>"
		echo "				<version>${data##*:}</version>"
		echo "			</dependency>"
	done < "${_PROJECTS_DIR}/liferay-portal-ee/modules/releng-pom-compile-only-dependencies.properties"

	echo "			<dependency>"
	echo "				<groupId>com.liferay.portal</groupId>"
	echo "				<artifactId>release.dxp.api</artifactId>"
	echo "				<version>${_DXP_VERSION}</version>"
	echo "			</dependency>"

}

function generate_bom_full {
	rm -f /tmp/bom
	for jar_file in $(find "${_BUNDLES_DIR}" -name "*.jar")
	do
		local manifest=$(get_jar_manifest "${jar_file}" | sed -r "s/\\r?\\n //g" -z)

		local bundle_symbolic_name=$(echo -en "${manifest}" | grep "Bundle-SymbolicName:" | tr -d [:space:])

		bundle_symbolic_name=${bundle_symbolic_name#Bundle-SymbolicName:}

		local bundle_version=$(echo -en "${manifest}" | grep "Bundle-Version:" | tr -d [:space:])

		bundle_version=${bundle_version#Bundle-Version:}

		if [ -z "${bundle_symbolic_name}" ] || [ -z "${bundle_version}" ]
		then
			continue
		fi

		local group_id=com.liferay

		echo "${group_id},${bundle_symbolic_name},${bundle_version}" >> /tmp/bom
		echo "${group_id},${jar_file},${bundle_symbolic_name},${bundle_version}" >> /tmp/bomfull


		echo "			<dependency>"
		echo "				<groupId>com.liferay</groupId>"
		echo "				<artifactId>${bundle_symbolic_name}</artifactId>"
		echo "				<version>${bundle_version}</version>"
		echo "			</dependency>"
	done

	cat /tmp/bom | sort > /tmp/bs
}

function generate_boms {
	generate_bom compile_only .compile.only

	generate_bom full
	exit 1
}

function get_jar_manifest {
	unzip -p "${1}" META-INF/MANIFEST.MF
}