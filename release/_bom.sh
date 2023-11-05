#!/bin/bash

function generate_poms {
	if (! echo "${_DXP_VERSION}" | grep -q "q")
	then
		echo "Only generating BOMs for quarterly updates."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local base_version=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.profile-dxp.properties "release.info.version").u$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.trivial")

	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	for pom in release.dxp.bom release.dxp.bom.compile.only
	do
		lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/${pom}/${base_version}/${pom}-${base_version}.pom"

		sed -e "s#<version>${base_version}</version>#<version>${_DXP_VERSION}</version>#" < "${pom}-${base_version}.pom" | \
		sed -e "s#<connection>scm:git:git@github.com:liferay/liferay-portal.git</connection>#<connection>scm:git:git@github.com:liferay/liferay-dxp.git</connection>#" | \
		sed -e "s#<developerConnection>scm:git:git@github.com:liferay/liferay-portal.git</developerConnection>#<developerConnection>scm:git:git@github.com:liferay/liferay-dxp.git</developerConnection>#" | \
		sed -e "s#<tag>.*</tag>#<tag>${_DXP_VERSION}</tag>#" | \
		sed -e "s#<url>https://github.com/liferay/liferay-portal</url>#<url>https://github.com/liferay/liferay-dxp</url>#" > "${pom}-${_DXP_VERSION}.pom"

		rm -f "${pom}-${base_version}.pom"
	done
}