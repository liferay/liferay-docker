#!/bin/bash

function generate_boms {
	if (! echo "${_DXP_VERSION}" | grep -q "q")
	then
		echo "Only generating BOMs for quarterly updates."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local base_version=$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.profile-dxp.properties "release.info.version").u$(lc_get_property "${_PROJECTS_DIR}"/liferay-portal-ee/release.properties "release.info.version.trivial")

	mkdir -p "${_BUILD_DIR}/boms"

	lc_cd "${_BUILD_DIR}/boms"

	lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/release.dxp.bom/${base_version}/release.dxp.bom-${base_version}.pom"

	lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/release.dxp.bom.compile.only/${base_version}/release.dxp.bom.compile.only-${base_version}.pom"

	lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/release.dxp.api/${base_version}/release.dxp.api-${base_version}.jar"

	lc_download "https://repository.liferay.com/nexus/service/local/repositories/liferay-public-releases/content/com/liferay/portal/release.dxp.api/${base_version}/release.dxp.api-${base_version}-sources.jar"

	sed -e "s#<version>${base_version}</version>#<version>${_DXP_VERSION}</version>#" < release.dxp.bom-${base_version}.pom > release.dxp.bom-${_DXP_VERSION}.pom

	return 1
}
