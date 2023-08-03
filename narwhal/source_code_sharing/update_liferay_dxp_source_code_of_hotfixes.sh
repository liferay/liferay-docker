#!/bin/bash

# shellcheck disable=2002,2013

#set -e
set -o pipefail

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

BASE_DIR="${PWD}"

LIFERAY_COMMON_DOWNLOAD_MAX_TIME="120"

REPO_PATH_DXP="${BASE_DIR}/liferay-dxp"
REPO_PATH_EE="${BASE_DIR}/liferay-portal-ee"

function check_if_tag_exists {
	local repository="${1}"
	local tag_name="${2}"

	lc_cd "${BASE_DIR}/${repository}"

	if (git -P tag -l "${tag_name}" | grep -q "[[:alnum:]]")
	then
		lc_log DEBUG "The tag '${tag_name}' already exists in the ${repository} repository."

		return 0
	else
		lc_log DEBUG "The tag '${tag_name}' does not exist in the ${repository} repository."

		return 1
	fi
}

function check_ignore_zip_file {
	local hotfix_zip_file="${1}"
	local release_version="${2}"

	local file_url="${STORAGE_URL}/${release_version}/hotfix/${hotfix_zip_file}"

	if [[ "x${IGNORE_ZIP_FILES}" =~ x*${hotfix_zip_file}* ]]
	then
		lc_log WARNING "Ignoring '${file_url}'."

		return 0
	else
		lc_log DEBUG "The file on '${file_url}' is not on the ignore list."

		return 1
	fi
}


function check_usage {
	LIFERAY_COMMON_DEBUG_ENABLED="false"
	LIFERAY_COMMON_LOG_DIR="${PWD}/logs"
	IGNORE_ZIP_FILES=""
	RUN_FETCH_REPOSITORY="true"
	RUN_PUSH_TO_ORIGIN="true"
	STORAGE_LOCATION="us"
	ZIP_LIST_RETENTION_TIME="1 min"
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

			-r|--zip-list-retention-time)
				ZIP_LIST_RETENTION_TIME="${2}"

				shift 1

				;;

			-s|--storage-location)
				STORAGE_LOCATION="${2}"

				shift 1

				;;

			-v|--version)
				VERSION_INPUT="${2}"

				shift 1

				;;

			--no-fetch)
				RUN_FETCH_REPOSITORY="false"

				;;

			--no-push)
				RUN_PUSH_TO_ORIGIN="false"

				;;

			*)
				print_help

				;;
		esac

		shift 1
	done

	process_argument_storage_location

	process_argument_version
}

function checkout_commit {
	repository="${1}"
	commit_hash="${2}"

	lc_cd "${BASE_DIR}/${1}"

	if git cat-file -e "${commit_hash}"
	then
		git reset --hard
		git clean -fdX

		git checkout -f "${commit_hash}"
	else
		lc_log ERROR "The commit '${commit_hash}' is missing in the repository 'liferay-portal-ee'."

		exit "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function copy_hotfix_commit {
	local commit_hash="${1}"
	local tag_name_base="${2}"
	local tag_name_new="${3}"

	lc_time_run checkout_commit liferay-portal-ee "${commit_hash}"

	lc_time_run checkout_tag liferay-dxp "${tag_name_base}"

	lc_time_run run_git_maintenance

	lc_time_run run_rsync

	lc_time_run commit_and_tag "${tag_name_new}"

	lc_time_run push_to_origin "${tag_name_new}"

	echo ""
}

function get_hotfix_properties {
	local cache_file="${1}"

	if [ ! -f "${cache_file}" ]
	then
		lc_log ERROR "Cache file '${cache_file}' not found."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local tmp_fix_pack_documentation="/tmp/${cache_file##*/}"

	if (! unzip -p "${cache_file}" fixpack_documentation.json > "${tmp_fix_pack_documentation}")
	then
		lc_log ERROR "No fixpack_documentation.json file found in '${cache_file}'."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	GIT_REVISION=$(jq -r '.build."git-revision"' "${tmp_fix_pack_documentation}")
	PATCH_PRODUCT=$(jq -r '.patch."product"' "${tmp_fix_pack_documentation}")
	PATCH_REQUIREMENTS=$(jq -r '.patch."requirements"' "${tmp_fix_pack_documentation}")

	rm -f "${tmp_fix_pack_documentation}"

	if [[ "${PATCH_PRODUCT}" == "7413" ]] && [[ "${PATCH_REQUIREMENTS}" == base-* ]]
	then
		PATCH_REQUIREMENTS="ga1"
	fi

	lc_log DEBUG "GIT_REVISION: '${GIT_REVISION}'."
	lc_log DEBUG "PATCH_PRODUCT: '${PATCH_PRODUCT}'."
	lc_log DEBUG "PATCH_REQUIREMENTS: '${PATCH_REQUIREMENTS}'."

	if [[ "${PATCH_REQUIREMENTS}" != +(ga1|u[1-9]*) ]]
	then
		lc_log DEBUG "No match of patch.requirements attribute: '${PATCH_REQUIREMENTS}'."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function get_hotfix_zip_list_file {
	local release_version="${1}"
	local zip_list_file="${2}"

	local is_new_file

	if [ -f "${zip_list_file}" ]
	then
		is_new_file=$(find "${zip_list_file}" -newermt "${ZIP_LIST_RETENTION_TIME} ago")
	fi

	if [ -n "${is_new_file}" ]
	then
		lc_log DEBUG "The file '${zip_list_file}' is new enough, using it."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log DEBUG "Downloading the zip list file: '${zip_list_file}'."

		if (! curl --fail --max-time "${LIFERAY_COMMON_DOWNLOAD_MAX_TIME}" --show-error --silent "${STORAGE_URL}/${release_version}/hotfix/" | grep -E -o "liferay-hotfix-[0-9-]+.zip" | uniq - "${zip_list_file}")
			then
				lc_log ERROR "The '${zip_list_file}' cannot be downloaded."

				exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi
}

function main {
	check_usage "${@}"

	prepare_cache_dir

	prepare_repositories

	process_version_list "${VERSION_LIST[@]}"
}

function prepare_cache_dir {
	install -d -m 0700 "${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}"
}

function print_help {
	echo "Usage: ${0} [-d|--debug] [-i|--ignore-zip-files <file1,...,fileN>] [-l|--logdir <logdir>] [-r|--zip-list-retention-time '<time>'] [-s|--storage-location <BUD|LAX>] [-v|--version <version>] [--no-fetch] [--no-push]"
	echo ""
	echo "    -d|--debug (optional):                                  Enabling debug mode"
	echo "    -i|--ignore-zip-files <file1,...,fileN> (optional):     Comma-separated list of files to be not processed (useful if a file is corrupted on the remote server)"
	echo "    -l|--logdir <logdir> (optional):                        Logging directory, defaults to \"\${PWD}/logs\""
	echo "    -r|--zip-list-retention-time '<time>' (optinal):        Retention time after the update of the zip list is enforced, defaults to '1 min'"
	echo "    -s|--storage-location <BUD|LAX> (optinal):              Location of the zip files, defaults to 'LAX'"
	echo "    -v|--version <version> (optional):                      Version to handle, defaults to \"7.4.13\""
	echo "    --no-fetch (optional):                                  Do not fetch DXP repo"
	echo "    --no-push (optional):                                   Do not push to origin"
	echo ""
	echo "Example (equals to no arguments):"
	echo ""
	echo "${0} -l \"\${PWD}/logs\" -r '1 min' -s LAX -v '7.4.13'"
	echo ""

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function process_argument_storage_location {
	case "${STORAGE_LOCATION}" in
		BUD)
			STORAGE_URL="http://storage.bud.liferay.com/public/files.liferay.com/private/ee/fix-packs"

			;;

		LAX)
			STORAGE_URL="https://files.liferay.com/private/ee/fix-packs"

			;;

		*)
			lc_log ERROR "Unknown location: ${STORAGE_LOCATION}".

			exit 1

			;;
	esac
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

		lc_log DEBUG "Processing version: ${release_version}."

		lc_time_run get_hotfix_zip_list_file "${release_version}" "${zip_list_file}"

		process_zip_list_file "${zip_list_file}" "${release_version}"
	done
}

function process_zip_list_file {
	local zip_list_file="${1}"
	local release_version="${2}"

	for hotfix_zip_file in $(cat "${zip_list_file}")
	do
		lc_log DEBUG "Processing ${hotfix_zip_file}."

		local tag_name_new

		tag_name_new="${hotfix_zip_file%.zip}"
		tag_name_new="${tag_name_new#liferay-}"

		check_if_tag_exists liferay-dxp "${tag_name_new}" && continue

		check_ignore_zip_file "${hotfix_zip_file}" "${release_version}" && continue

		file_url="${STORAGE_URL}/${release_version}/hotfix/${hotfix_zip_file}"

		lc_time_run lc_download "${file_url}"

		local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

		lc_time_run get_hotfix_properties "${cache_file}"

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
		then
			continue
		fi

		copy_hotfix_commit "${GIT_REVISION}" "${release_version}-${PATCH_REQUIREMENTS}" "${tag_name_new}"
	done
}

main "${@}"
