#!/bin/bash

source ../_liferay_common.sh
source ./_bom.sh
source ./_git.sh
source ./_package.sh
source ./_product.sh
source ./_promotion.sh

function check_usage {
	if [ -z "${LIFERAY_RELEASE_PRODUCT_NAME}" ] ||
	   [ -z "${LIFERAY_RELEASE_VERSION}" ]
	then
		print_help
	fi

	LIFERAY_RELEASE_UPLOAD="true"
	_BUILD_TIMESTAMP=$(date +%s)

	LIFERAY_RELEASE_RC_BUILD_TIMESTAMP="${_BUILD_TIMESTAMP}"

	set_product_version "${LIFERAY_RELEASE_VERSION}" "${_BUILD_TIMESTAMP}"

	_RELEASE_TOOL_DIR=$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")

	lc_cd "${_RELEASE_TOOL_DIR}"

	mkdir -p release-data

	lc_cd release-data

	_RELEASE_ROOT_DIR="${PWD}"

	_BUILD_DIR="${_RELEASE_ROOT_DIR}"/build

	LIFERAY_COMMON_LOG_DIR="${_BUILD_DIR}"
	_PROMOTION_DIR="${_BUILD_DIR}"/release

	_PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/dev/projects

	_BUNDLES_DIR="${_PROJECTS_DIR}"/bundles
}

function checkout_product_version {
	lc_cd "${_PROJECTS_DIR}"/liferay-portal-ee

	git clean -d --force -x

	git reset --hard

	git checkout master

	local product_version_tag=$(echo "${_PRODUCT_VERSION}" | sed --regexp-extended "s/-lts//g")

	git branch --delete "${product_version_tag}" 2> /dev/null
	git tag --delete "${product_version_tag}" 2> /dev/null

	git fetch --no-tags upstream "${product_version_tag}":"${product_version_tag}"

	git checkout "${product_version_tag}"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to checkout to ${product_version_tag}."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function main {
	if [[ " ${@} " =~ " --test " ]]
	then
		return
	fi

	check_usage

	lc_time_run clone_repository liferay-portal-ee

	lc_time_run checkout_product_version

	lc_time_run compile_product

	lc_time_run build_product

	lc_time_run generate_api_jars

	lc_time_run generate_api_source_jar

	lc_time_run generate_distro_jar

	lc_time_run generate_poms

	rm --force --recursive "${_BUILD_DIR}/release"

	mkdir -p "${_BUILD_DIR}/release"

	lc_time_run package_boms

	lc_time_run generate_checksum_files

	lc_time_run promote_boms
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD=<password> LIFERAY_RELEASE_NEXUS_REPOSITORY_USER=<user> LIFERAY_RELEASE_PRODUCT_NAME=<product_name> LIFERAY_RELEASE_VERSION=<version> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD (optional): Nexus user's password"
	echo "    LIFERAY_RELEASE_NEXUS_REPOSITORY_USER (optional): Nexus user with the right to upload BOM files"
	echo "    LIFERAY_RELEASE_PRODUCT_NAME: Set to \"portal\" for CE. The default is \"DXP\"."
	echo "    LIFERAY_RELEASE_UPLOAD (optional): Set this to \"true\" to upload artifacts"
	echo "    LIFERAY_RELEASE_VERSION: DXP or Portal version of the release to publish"
	echo ""
	echo "Example: LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD=123456789 LIFERAY_RELEASE_NEXUS_REPOSITORY_USER=joe.bloggs@liferay.com LIFERAY_RELEASE_PRODUCT_NAME=dxp LIFERAY_RELEASE_VERSION=2023.q3.0 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main "${@}"