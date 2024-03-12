#!/bin/bash

source _bom.sh
source _git.sh
source _hotfix.sh
source _jdk.sh
source _liferay_common.sh
source _package.sh
source _patcher.sh
source _product.sh
source _publishing.sh

function check_usage {

	#
	# TODO Remove once all systems are using LIFERAY_RELEASE_GIT_REF instead of LIFERAY_RELEASE_GIT_SHA
	#

	if [ -z "${LIFERAY_RELEASE_GIT_REF}" ]
	then
		LIFERAY_RELEASE_GIT_REF=${LIFERAY_RELEASE_GIT_SHA}
	fi

	if [ -z "${LIFERAY_RELEASE_GIT_REF}" ]
	then
		print_help
	fi

	_BUILD_TIMESTAMP=$(date +%s)

	if [ -z "${LIFERAY_RELEASE_HOTFIX_ID}" ]
	then
		LIFERAY_RELEASE_HOTFIX_ID=${_BUILD_TIMESTAMP}
	fi

	if [ -z "${LIFERAY_RELEASE_PRODUCT_NAME}" ]
	then
		LIFERAY_RELEASE_PRODUCT_NAME=dxp
	fi

	_RELEASE_TOOL_DIR=$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")

	lc_cd "${_RELEASE_TOOL_DIR}"

	mkdir -p release-data

	lc_cd release-data

	_RELEASE_ROOT_DIR="${PWD}"

	_BUILD_DIR="${_RELEASE_ROOT_DIR}"/build
	_BUILDER_SHA=$(git rev-parse HEAD)
	_BUNDLES_DIR="${_RELEASE_ROOT_DIR}"/dev/projects/bundles
	_PROJECTS_DIR="${_RELEASE_ROOT_DIR}"/dev/projects
	_RELEASES_DIR="${_RELEASE_ROOT_DIR}"/releases
	_TEST_RELEASE_DIR="${_RELEASE_ROOT_DIR}"/test_release

	LIFERAY_COMMON_LOG_DIR="${_BUILD_DIR}"
}

function main {
	export ANT_OPTS="-Xmx10G"

	print_variables

	check_usage

	lc_time_run configure_jdk

	lc_time_run report_jenkins_url

	lc_background_run clone_repository liferay-binaries-cache-2020
	lc_background_run clone_repository liferay-portal-ee
	lc_background_run clone_repository liferay-release-tool-ee

	lc_wait

	lc_time_run clean_portal_repository

	lc_background_run init_gcs
	lc_background_run update_portal_repository

	lc_wait

	lc_time_run set_git_sha

	lc_background_run decrement_module_versions
	lc_background_run update_release_tool_repository

	lc_wait

	lc_time_run set_product_version

	if [ "${LIFERAY_RELEASE_OUTPUT}" != "hotfix" ]
	then
		lc_time_run update_release_info_date

		lc_time_run set_up_profile

		lc_time_run add_licensing

		lc_time_run compile_product

		lc_time_run obfuscate_licensing

		lc_time_run build_product

		lc_background_run build_sql
		lc_background_run copy_copyright
		lc_background_run deploy_elasticsearch_sidecar
		lc_background_run clean_up_ignored_dxp_modules
		lc_background_run clean_up_ignored_dxp_plugins

		lc_wait

		lc_time_run warm_up_tomcat

		lc_time_run install_patching_tool

		lc_time_run generate_api_jars

		lc_time_run generate_api_source_jar

		lc_time_run generate_poms

		generate_poms_from_scratch

		lc_time_run package_release

		lc_time_run package_boms

		lc_time_run generate_checksum_files

		lc_time_run generate_release_properties_file

		lc_time_run generate_release_notes

		lc_time_run upload_boms xanadu

		lc_time_run upload_release
	else
		lc_time_run prepare_release_dir

		lc_time_run copy_release_info_date

		lc_time_run set_up_profile

		lc_time_run add_hotfix_testing_code

		lc_time_run set_hotfix_name

		lc_time_run add_licensing

		lc_time_run compile_product

		lc_time_run obfuscate_licensing

		lc_time_run build_product

		lc_time_run clean_up_ignored_dxp_modules

		lc_time_run clean_up_ignored_dxp_plugins

		lc_time_run add_portal_patcher_properties_jar

		lc_time_run create_hotfix

		lc_time_run calculate_checksums

		lc_time_run create_documentation

		lc_time_run sign_hotfix

		lc_time_run package_hotfix

		lc_time_run upload_hotfix

		lc_time_run report_patcher_status
	fi

	local end_time=$(date +%s)

	local seconds=$((end_time - _BUILD_TIMESTAMP))

	lc_log INFO "Completed ${LIFERAY_RELEASE_OUTPUT} building in $(lc_echo_time ${seconds}) on $(date)."

	if [ -e "${_BUILD_DIR}/output.md" ]
	then
		echo ""

		cat "${_BUILD_DIR}/output.md"
	fi
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_GIT_REF=<git sha> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_GCS_TOKEN (optional): *.json file containing the token to authenticate with Google Cloud Storage"
	echo "    LIFERAY_RELEASE_GIT_REF: Git SHA to build from"
	echo "    LIFERAY_RELEASE_HOTFIX_BUILD_ID (optional): Build ID on Patcher"
	echo "    LIFERAY_RELEASE_HOTFIX_FIXED_ISSUES (optional): Comma delimited list of fixed issues in the hotfix"
	echo "    LIFERAY_RELEASE_HOTFIX_ID (optional): Hotfix ID"
	echo "    LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_FILE (optional): *.pem file containing the hotfix signing key"
	echo "    LIFERAY_RELEASE_HOTFIX_SIGNATURE_KEY_PASSWORD (optional): Password to unlock the hotfix signing key"
	echo "    LIFERAY_RELEASE_HOTFIX_TEST_SHA (optional): Git commit to cherry pick to build a test hotfix"
	echo "    LIFERAY_RELEASE_HOTFIX_TEST_TAG (optional): Tag name of the hotfix testing code in the liferay-portal-ee repository"
	echo "    LIFERAY_RELEASE_OUTPUT (optional): Set this to \"hotfix\" to build a hotfix instead of a release"
	echo "    LIFERAY_RELEASE_PATCHER_REQUEST_KEY (optional): Request key from Patcher that is used to report back statuses to Patcher"
	echo "    LIFERAY_RELEASE_PATCHER_USER_ID (optional): User ID of the patcher user who started the build"
	echo "    LIFERAY_RELEASE_PRODUCT_NAME (optional): Set to \"portal\" for CE. The default is \"DXP\"."
	echo "    LIFERAY_RELEASE_UPLOAD (optional): Set this to \"true\" to upload artifacts"
	echo ""
	echo "Example: LIFERAY_RELEASE_GIT_REF=release-2023.q3 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function print_variables {
	echo "To reproduce this build locally, execute the following command in liferay-docker/release:"

	local environment=$(set | \
		grep -e "^LIFERAY_RELEASE" | \
		grep -v "LIFERAY_RELEASE_GCS_TOKEN" | \
		grep -v "LIFERAY_RELEASE_HOTFIX_SIGNATURE" | \
		grep -v "LIFERAY_RELEASE_PATCHER_REQUEST_KEY" | \
		grep -v "LIFERAY_RELEASE_UPLOAD" | \
		tr "\n" " ")

	echo "${environment}./build_release.sh"
	echo ""
}

main