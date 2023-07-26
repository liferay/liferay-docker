#!/bin/bash

# shellcheck disable=2002,2013

#set -e
set -o pipefail

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

BASE_DIR="${PWD}"

LIFERAY_COMMON_LOG_DIR="${PWD}/logs"

REPO_PATH_DXP="${BASE_DIR}/liferay-dxp"
REPO_PATH_EE="${BASE_DIR}/liferay-portal-ee"

ZIP_LIST_URL="https://files.liferay.com/private/ee/fix-packs"

function check_if_file_is_cached {
	# FIXME: should be added to download() too

	local file_url="${1}"

	if [ -z "${file_url}" ]
	then
		lc_log ERROR "File URL is not set."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

	lc_log DEBUG "Cache file: ${cache_file}."

	if [ -e "${cache_file}" ]
	then
		lc_log DEBUG "The file of ${file_url} is already in cache."
	else
		lc_log DEBUG "The file of ${file_url} is not in cache."

		return 1
	fi
}

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
	RUN_FETCH_REPOSITORY="yes"
	RUN_PUSH_TO_ORIGIN="yes"
	VERSION_INPUT="7.4.13"

	while [ "$#" -gt "0" ]
	do
		case "${1}" in
			-d|--debug)
				LIFERAY_COMMON_LOG_LEVEL="DEBUG"

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

function download_file_to_cache {
	# FIXME: should be added to download() too

	local file_url="${1}"

	if [ -z "${file_url}" ]
	then
		lc_log ERROR "File URL is not set."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local dir_of_cache_file
	dir_of_cache_file=$(dirname "${cache_file}")

	mkdir -p "${dir_of_cache_file}"

	lc_log DEBUG "Downloading ${file_url}."

	local current_date
	current_date=$(lc_date)

	local temp_timestamp
	temp_timestamp="temp_$(lc_date "${current_date}" "+%Y%m%d%H%M%S")"

	if (curl "${file_url}" --fail --max-time 120 --output "${cache_file}.${temp_timestamp}" --show-error --silent)
	then
		mv "${cache_file}.${temp_timestamp}" "${cache_file}"
	else
		lc_log INFO "Unable to download ${file_url}. It needs to be reported to the IT team."

		rm -f "${cache_file}.${temp_timestamp}"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi
}

function get_hotfix_properties {
	local tmp_json
	tmp_json=$(mktemp "/tmp/json.XXX")

	unzip -p "${1}" fixpack_documentation.json > "${tmp_json}"

	GIT_REVISION=$(jq -r '.build."git-revision"' "${tmp_json}")
	PATCH_NAME=$(jq -r '.patch."name"' "${tmp_json}")
	PATCH_REQUIREMENTS=$(jq -r '.patch."requirements"' "${tmp_json}")

	if [[ "${PATCH_REQUIREMENTS}" == base-* ]]
		then
			PATCH_REQUIREMENTS="ga1"
	fi

	lc_log DEBUG "GIT_REVISION: ${GIT_REVISION}"
	lc_log DEBUG "PATCH_NAME: ${PATCH_NAME}"
	lc_log DEBUG "PATCH_REQUIREMENTS: ${PATCH_REQUIREMENTS}"

	if [[ "${PATCH_REQUIREMENTS}" != +(ga1|u[1-9]*) ]]
	then
		lc_log DEBUG "Not copying, patch.requirements: ${PATCH_REQUIREMENTS}"

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	rm -f "${tmp_json}"
}

function get_hotfix_zip_list_file {
	local release_version="${1}"
	local zip_list_file="${2}"

	local is_new_file

	if [ -f "${zip_list_file}" ]
	then
		is_new_file=$(find "${zip_list_file}" -newermt "1 day ago" 2>/dev/null)
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
	set +x
}

function print_help {
	echo ""
	echo "Usage:"
	echo ""
	echo "${0} [-l|--logdir <logdir>] [-v|--version <version>] [--no-fetch] [--no-push]"
	echo ""
	echo "    -d|--debug (optional):                Enabling debug mode"
	echo "    -l|--logdir <logdir> (optional):      Logging directory, defaults to \"\${PWD}/logs\""
	echo "    -v|--version <version> (optional):    Version to handle, defaults to \"7.4.13\""
	echo "    --no-fetch (optional):                Do not fetch DXP repo"
	echo "    --no-push (optional):                 Do not push to origin"
	echo ""
	echo "Default (equal to no arguments):"
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

	local cache_file="${ZIP_LIST_URL}/${release_version}/hotfix/${hotfix_zip_file}"

	for hotfix_zip_file in $(cat "${zip_list_file}")
	do
		lc_log DEBUG "Processing ${hotfix_zip_file}"

		if (check_if_tag_exists liferay-dxp "${release_version}" "${hotfix_zip_file}")
		then
			continue
		fi

		local file_url="${ZIP_LIST_URL}/${release_version}/hotfix/${hotfix_zip_file}"

		if (check_if_file_is_cached "${file_url}")
		then
			lc_log DEBUG "The file on ${file_url} is already in cache, skipping downloading."
		else
			lc_time_run download_file_to_cache "${file_url}"

			if [ "$?" = "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}" ]
			then
				continue
			fi
		fi

		local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

		if get_hotfix_properties "${cache_file}"
		then
			copy_hotfix_commit "${GIT_REVISION}" "${release_version}-${PATCH_REQUIREMENTS}" "${release_version}-${PATCH_NAME}"
		else
			lc_log DEBUG "The properties of ${cache_file} does not meet the requirements."

			exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	done
}

main "${@}"
