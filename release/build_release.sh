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
	BUILD_DIR="${HOME}"/.liferay/release-builder/build
	BUNDLES_DIR="${HOME}"/.liferay/dev/projects/bundles
	BUILD_TIMESTAMP=$(date +%s)
	PROJECTS_DIR="${HOME}"/.liferay/dev/projects

	ENV ANT_OPTS="-Xmx10G"

	#
	# The id of the hotfix
	#

	NARWHAL_BUILD_ID=1

	#
	# The git tag or branch to check out from the liferay-portal-ee
	#
	NARWHAL_GIT_SHA=7.2.x

	#
	# Either release or fix pack
	#
	NARWHAL_OUTPUT=release

	#
	# The github username used to check out on the liferay-portal-ee repository. Should be used only for debugging purposes
	#
	NARWHAL_REMOTE=liferay

	#
	# Tag name in the liferay-portal-ee repository which contains the hotfix testing SHA-s if you would like to build a test hotfix
	#
	NARWHAL_HOTFIX_TESTING_TAG=

	#
	# Git SHA which would be cherry-picked on NARWHAL_GIT_SHA from the tree of NARWHAL_HOTFIX_TESTING_TAG to build a test hotfix
	#
	NARWHAL_HOTFIX_TESTING_SHA=

	#
	# If this is set, the files will be uploaded to the designated buckets
	#
	NARWHAL_UPLOAD=

	#
	# The name of the GCS bucket where the internal files should be copied
	#
	NARWHAL_GCS_INTERNAL_BUCKET=patcher-storage

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

		lc_time_run prepare_legal_files

		lc_time_run deploy_elasticsearch_sidecar

		lc_time_run cleanup_ignored_dxp_modules

		lc_time_run warm_up_tomcat

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

		lc_time_run cleanup_ignored_dxp_modules

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