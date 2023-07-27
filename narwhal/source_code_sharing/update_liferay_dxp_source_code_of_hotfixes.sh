#!/bin/bash

# shellcheck disable=2002,2013

#set -e
set -o pipefail

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

BASE_DIR="${PWD}"

LIFERAY_COMMON_LOG_DIR="${PWD}/logs"

REPO_PATH_DXP="${BASE_DIR}/liferay-dxp"
REPO_PATH_EE="${BASE_DIR}/liferay-portal-ee"

ZIP_LIST_URL="http://storage.bud.liferay.com/public/files.liferay.com/private/ee/fix-packs"

function check_if_tag_exists {
	local repository="${1}"
	local release_version="${2}"
	local hotfix_zip_file="${3}"

	tag_name_new="${hotfix_zip_file%-*}"
	tag_name_new="${tag_name_new#*-}"
	tag_name_new="${release_version}-${tag_name_new}"


	lc_cd "${BASE_DIR}/${repository}"

	if (git -P tag -l "${tag_name_new}" | grep -q "[[:alnum:]]")
	then
		lc_log DEBUG "The tag '${tag_name_new}' already exists in the ${repository} repository."

		return 0
	else
		lc_log DEBUG "The tag '${tag_name_new}' does not exist in the ${repository} repository."

		return 1
	fi
}

function check_usage {
	LIFERAY_COMMON_DEBUG_ENABLED="no"
	LIFERAY_COMMON_LOG_DIR="${PWD}/logs"
	IGNORE_ZIP_FILES=""
	RUN_FETCH_REPOSITORY="yes"
	RUN_PUSH_TO_ORIGIN="yes"
	VERSION_INPUT="7.4.13"

	while [ "$#" -gt "0" ]
	do
		case "${1}" in
			-d|--debug)
				LIFERAY_COMMON_LOG_LEVEL="DEBUG"

				;;

			-i|--ignore-zip-files)
				IGNORE_ZIP_FILES="${2}"

				shift 1

				;;

			-l|--logdir)
				LIFERAY_COMMON_LOG_DIR="${2}"

				shift 1

				;;

			-v|--version)
				VERSION_INPUT="${2}"

				shift 1

				;;

			--no-fetch)
				RUN_FETCH_REPOSITORY="no"

				;;

			--no-push)
				RUN_PUSH_TO_ORIGIN="no"

				;;

			*)
				print_help

				;;
		esac

		shift 1
	done
}

function checkout_tag_dxp {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	local tag_name_base="${2}"

	lc_cd "${BASE_DIR}/${1}"

	git reset --hard -q
	git clean -fdqX

	git checkout -f -q "${tag_name_base}"
}

function copy_hotfix_commit {
	local commit_hash="${1}"
	local tag_name_base="${2}"
	local tag_name_new="${3}"

	lc_time_run checkout_commit liferay-portal-ee "${commit_hash}"

	local return_code="${?}"

	if [ "${return_code}" == "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
	then
		lc_log INFO "The commit '${commit_hash}' is missing in the repository 'liferay-portal-ee'."
		echo ""

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_time_run checkout_tag_dxp liferay-dxp "${tag_name_base}"

	lc_time_run run_git_maintenance

	lc_time_run run_rsync

	lc_time_run commit_and_tag "${tag_name_new}"

	lc_time_run push_to_origin "${tag_name_new}"

	echo ""
}

function get_hotfix_properties {
	local tmp_json

	tmp_json=$(mktemp "/tmp/json.XXX")

	unzip -p "${1}" fixpack_documentation.json > "${tmp_json}"

	GIT_REVISION=$(jq -r '.build."git-revision"' "${tmp_json}")
	PATCH_NAME=$(jq -r '.patch."name"' "${tmp_json}")
	PATCH_REQUIREMENTS=$(jq -r '.patch."requirements"' "${tmp_json}")

	rm -f "${tmp_json}"

	if [[ "${PATCH_REQUIREMENTS}" == base-* ]]
	then
		PATCH_REQUIREMENTS="ga1"
	fi

	lc_log DEBUG "GIT_REVISION: ${GIT_REVISION}"
	lc_log DEBUG "PATCH_NAME: ${PATCH_NAME}"
	lc_log DEBUG "PATCH_REQUIREMENTS: ${PATCH_REQUIREMENTS}"

	if [[ "${PATCH_REQUIREMENTS}" != +(ga1|u[1-9]*) ]]
	then
		lc_log DEBUG "Not copying, inappropriate patch.requirements attribute: '${PATCH_REQUIREMENTS}'"

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function get_hotfix_zip_list_file {
	local release_version="${1}"
	local zip_list_file="${2}"

	local is_new_file

	if [ -f "${zip_list_file}" ]
	then
		is_new_file=$(find "${zip_list_file}" -newermt "1 day ago")
	fi

	if [ -n "${is_new_file}" ]
	then
		lc_log DEBUG "The file '${zip_list_file}' is new enough, using it."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log DEBUG "Downloading the zip list file: '${zip_list_file}'"

		curl --fail --show-error --silent "${ZIP_LIST_URL}/${release_version}/hotfix/" | grep -E -o "liferay-hotfix-[0-9-]+.zip" | uniq > "${zip_list_file}"
	fi
}

function main {
	check_usage "${@}"

	prepare_cache_dir

	prepare_repositories

	process_argument_version

	process_version_list "${VERSION_LIST[@]}"
}

function prepare_cache_dir {
	install -d -m 0700 "${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}"
}

function prepare_repositories {
	lc_time_run clone_repository liferay-dxp

	lc_time_run clone_repository liferay-portal-ee

	lc_time_run fetch_repository liferay-dxp

	lc_time_run fetch_repository liferay-portal-ee
}

function print_help {
	echo "Usage: ${0} [-d|--debug] [-i|--ignore-zip-files <file1,...,fileN>] [-l|--logdir <logdir>] [-v|--version <version>] [--no-fetch] [--no-push]"
	echo ""
	echo "    -d|--debug (optional):                                  Enabling debug mode"
	echo "    -i|--ignore-zip-files <file1,...,fileN> (optional):     List of files separated by comma that are not processed (useful if file is corrupted on the server)"
	echo "    -l|--logdir <logdir> (optional):                        Logging directory, defaults to \"\${PWD}/logs\""
	echo "    -v|--version <version> (optional):                      Version to handle, defaults to \"7.4.13\""
	echo "    --no-fetch (optional):                                  Do not fetch DXP repo"
	echo "    --no-push (optional):                                   Do not push to origin"
	echo ""
	echo "Example (equals to no arguments):"
	echo ""
	echo "${0} -l \"\$PWD/logs\" -v \"7.4.13\""
	echo ""

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function process_argument_version {
	local IFS=" "

	read -r -a VERSION_ARRAY <<< "${VERSION_INPUT}"

	VERSION_LIST=("${VERSION_ARRAY[@]}")
}

function process_version_list {
	local version_list=("${@}")

	for release_version in "${version_list[@]}"
	do
		local zip_list_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/list-of-${release_version}.txt"

		lc_log DEBUG "Processing version: ${release_version}"

		lc_time_run get_hotfix_zip_list_file "${release_version}" "${zip_list_file}"

		process_zip_list_file "${zip_list_file}" "${release_version}"
	done
}

function process_zip_list_file {
	local zip_list_file="${1}"
	local release_version="${2}"

	for hotfix_zip_file in $(cat "${zip_list_file}")
	do
		local file_url="${ZIP_LIST_URL}/${release_version}/hotfix/${hotfix_zip_file}"

		if [[ "x${IGNORE_ZIP_FILES}" =~ x*${hotfix_zip_file}* ]]
		then
			lc_log WARNING "Ignoring the file of '${file_url}'."

			continue
		fi

		lc_log DEBUG "Processing ${hotfix_zip_file}"

		check_if_tag_exists liferay-dxp "${release_version}" "${hotfix_zip_file}" && continue

		lc_time_run lc_download "${file_url}"

		local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

		lc_time_run get_hotfix_properties "${cache_file}"

		copy_hotfix_commit "${GIT_REVISION}" "${release_version}-${PATCH_REQUIREMENTS}" "${release_version}-${PATCH_NAME}"
	done
}

main "${@}"
