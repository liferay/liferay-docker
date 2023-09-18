#!/bin/bash

source _dxp.sh
source _git.sh
source _hotfix.sh
source _liferay_common.sh
source _package.sh
source _publishing.sh

function background_run {
	if [ -n "${LIFERAY_COMMON_DEBUG_ENABLED}" ]
	then
		lc_time_run "${@}"
	else
		lc_time_run "${@}" &
	fi
}

function check_usage {
	if [ ! -n "${LIFERAY_RELEASE_GIT_SHA}" ]
	then
		print_help
	fi

	if [ ! -n "${LIFERAY_RELEASE_HOTFIX_ID}" ]
	then
		LIFERAY_RELEASE_HOTFIX_ID=1
	fi
}

function main {
	ANT_OPTS="-Xmx10G"
	_BUILD_DIR="${HOME}"/.liferay-release/build
	_BUILD_TIMESTAMP=$(date +%s)
	_BUNDLES_DIR="${HOME}"/.liferay-release/dev/projects/bundles
	_PROJECTS_DIR="${HOME}"/.liferay-release/dev/projects

	LIFERAY_COMMON_LOG_DIR="${_BUILD_DIR}"

	check_usage

	background_run clone_repository liferay-binaries-cache-2020
	background_run clone_repository liferay-portal-ee
	background_run clone_repository liferay-release-tool-ee

	wait

	lc_time_run clean_portal_repository

	background_run init_gcs
	background_run update_portal_repository
	background_run update_release_tool_repository

	wait

	lc_time_run set_up_profile_dxp

	lc_time_run decrement_module_versions

	_DXP_VERSION=$(get_dxp_version)

	if [ "${LIFERAY_RELEASE_OUTPUT}" != "hotfix" ]
	then
		lc_time_run update_release_date

		lc_time_run add_licensing

		lc_time_run compile_dxp

		lc_time_run obfuscate_licensing

		lc_time_run build_dxp

		lc_time_run copy_copyright

		lc_time_run deploy_elasticsearch_sidecar

		lc_time_run clean_up_ignored_dxp_modules

		lc_time_run warm_up_tomcat

		lc_time_run package_release

		lc_time_run generate_checksum_files

		lc_time_run upload_release
	else
		lc_time_run add_hotfix_testing_code

		lc_time_run set_hotfix_name

		lc_time_run add_licensing

		lc_time_run compile_dxp

		lc_time_run obfuscate_licensing

		background_run build_dxp
		background_run prepare_release_dir

		wait

		lc_time_run clean_up_ignored_dxp_modules

		lc_time_run add_portal_patcher_properties_jar

		lc_time_run create_hotfix

		lc_time_run calculate_checksums

		lc_time_run create_documentation

		lc_time_run package_hotfix

		lc_time_run upload_hotfix
	fi

	local end_time=$(date +%s)

	local seconds=$((end_time - _BUILD_TIMESTAMP))

	lc_log INFO "Completed ${LIFERAY_RELEASE_OUTPUT} building in $(lc_echo_time ${seconds}) on $(date)."
}

function print_help {
	echo "Usage: LIFERAY_RELEASE_GIT_SHA=<git sha> ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    LIFERAY_RELEASE_GIT_SHA: Git SHA to build from"
	echo "    LIFERAY_RELEASE_HOTFIX_ID (optional): Hotfix ID"
	echo "    LIFERAY_RELEASE_HOTFIX_TEST_SHA (optional): Git commit to cherry pick to build a test hotfix"
	echo "    LIFERAY_RELEASE_HOTFIX_TEST_TAG (optional): Tag name of the hotfix testing code in the liferay-portal-ee repository"
	echo "    LIFERAY_RELEASE_OUTPUT (optional): Set this to \"hotfix\" to build a hotfix instead of a release"
	echo "    LIFERAY_RELEASE_UPLOAD (optional): Set this to \"true\" to upload artifacts"
	echo ""
	echo "Example: LIFERAY_RELEASE_GIT_SHA=release-2023.q3 ${0}"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

main