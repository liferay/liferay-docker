#!/bin/bash

source /usr/local/bin/set_java_version.sh

source /usr/local/bin/_dxp_util.sh
source /usr/local/bin/_git_util.sh
source /usr/local/bin/_hotfix_util.sh
source /usr/local/bin/_liferay_common.sh
source /usr/local/bin/_publishing_util.sh
source /usr/local/bin/_release_util.sh

function background_run {
	if [ -n "${LIFERAY_COMMON_DEBUG_ENABLED}" ]
	then
		lc_time_run "${@}"
	else
		lc_time_run "${@}" &
	fi
}


function main {
	BUILD_DIR=/opt/liferay/build
	BUNDLES_DIR=/opt/liferay/dev/projects/bundles
	BUILD_TIMESTAMP=$(date +%s)

	LIFERAY_COMMON_LOG_DIR=${BUILD_DIR}

	lc_time_run setup_git

	background_run clone_repository liferay-binaries-cache-2020
	background_run clone_repository liferay-portal-ee
	lc_time_run clone_repository liferay-release-tool-ee
	wait

	lc_time_run setup_remote

	lc_time_run clean_portal_git

	background_run init_gcs
	background_run update_portal_git
	lc_time_run update_release_tool_git
	wait

	lc_time_run pre_compile_setup

	lc_time_run decrement_module_versions

	DXP_VERSION=$(get_dxp_version)

	if [ "${NARWHAL_OUTPUT}" == "release" ]
	then
		lc_time_run add_licensing

		lc_time_run compile_dxp

		lc_time_run obfuscate_licensing

		lc_time_run build_dxp

		lc_time_run deploy_elasticsearch_sidecar

		#lc_time_run warm_up_tomcat

		lc_time_run package_bundle

		lc_time_run upload_bundle
	else
		lc_time_run add_hotfix_testing_code

		lc_time_run set_hotfix_name

		lc_time_run add_licensing

		lc_time_run compile_dxp

		lc_time_run obfuscate_licensing

		background_run prepare_release_dir
		lc_time_run build_dxp
		wait

		lc_time_run add_portal_patcher_properties_jar

		lc_time_run create_hotfix

		lc_time_run calculate_checksums

		lc_time_run create_documentation

		lc_time_run package_hotfix

		lc_time_run upload_hotfix
	fi

	local end_time=$(date +%s)
	local seconds=$((end_time - BUILD_TIMESTAMP))

	echo ">>> Completed ${NARWHAL_OUTPUT} building process in $(lc_echo_time ${seconds}). $(date)"
}

main