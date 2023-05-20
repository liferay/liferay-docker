#!/bin/bash

source /usr/local/bin/_dxp_util.sh
source /usr/local/bin/_git_util.sh
source /usr/local/bin/_hotfix_util.sh
source /usr/local/bin/_liferay_common.sh
source /usr/local/bin/_publishing_util.sh
source /usr/local/bin/_release_util.sh

function create_folders {
	BUILD_DIR=/opt/liferay/build

	mkdir -p "${BUILD_DIR}"

	echo 0 > "${BUILD_DIR}"/.step

	mkdir -p /opt/liferay/download_cache
}


function main {
	BUNDLES_DIR=/opt/liferay/dev/projects/bundles

	local start_time=$(date +%s)

	create_folders

	time_run setup_git

	background_run clone_repository liferay-binaries-cache-2020
	background_run clone_repository liferay-portal-ee
	time_run clone_repository liferay-release-tool-ee
	wait

	time_run setup_remote

	time_run clean_portal_git

	background_run init_gcs
	background_run update_portal_git
	time_run update_release_tool_git
	wait

	time_run pre_compile_setup

	time_run decrement_module_versions

	DXP_VERSION=$(get_dxp_version)

	if [ "${NARWHAL_OUTPUT}" == "release" ]
	then
		time_run add_licensing

		time_run compile_dxp

		time_run package_bundle

		time_run upload_bundle
	else
		time_run add_hotfix_testing_code

		time_run add_licensing

		background_run prepare_release_dir
		time_run compile_dxp
		wait

		time_run create_hotfix

		time_run calculate_checksums

		time_run create_documentation

		time_run package

		time_run upload_hotfix
	fi

	local end_time=$(date +%s)
	local seconds=$((end_time - start_time))

	echo ">>> Completed hotfix building process in $(echo_time ${seconds}). $(date)"
}

main