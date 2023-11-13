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

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	else
		lc_log DEBUG "The tag '${tag_name}' does not exist in the ${repository} repository."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_ignore_zip_file {
	local hotfix_zip_file="${1}"
	local release_version="${2}"

	local file_url="${zip_directory_url}/${hotfix_zip_file}"

	if [[ "x${IGNORE_ZIP_FILES}" =~ x*${hotfix_zip_file}* ]]
	then
		lc_log DEBUG "Ignoring '${file_url}'."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	else
		lc_log DEBUG "The file on '${file_url}' is not on the ignore list."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_patch_requirements {
	local patch_requirements="${1}"
	local tag_name_new="${2}"

	if [ "${tag_name_new}" == "${TAG_FORCE_COPY}" ]
	then
		lc_log DEBUG "Skipping the .patch.requirements check, the tag '${tag_name_new}' will be force copied regardless of the '.patch.requirements' property: '${patch_requirements}'."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	if [[ "${patch_requirements}" == +(ga1|u[1-9]*) ]]
	then
		lc_log DEBUG "The '.patch.requirements' property is suitable: '${patch_requirements}'."

		return "${LIFERAY_COMMON_EXIT_CODE_OK}"
	else
		lc_log DEBUG "The .patch.requirements property is unsuitable: '${patch_requirements}'. Skipping it."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function check_usage {
	LIFERAY_COMMON_DEBUG_ENABLED="false"
	LIFERAY_COMMON_LOG_DIR="${PWD}/logs"
	IGNORE_ZIP_FILES=""
	RUN_FETCH_REPOSITORY="true"
	RUN_PUSH_TO_ORIGIN="true"
	ZIP_LIST_RETENTION_TIME="1 min"
	VERSION_INPUT="7.3.10 7.4.13 2023.q3"

	while [ "$#" -gt "0" ]
	do
		case "${1}" in
			--debug)
				LIFERAY_COMMON_LOG_LEVEL="DEBUG"
				LIFERAY_COMMON_DEBUG_ENABLED="true"

				;;

			--ignore-zip-files)
				IGNORE_ZIP_FILES="${2}"

				shift 1

				;;

			--logdir)
				LIFERAY_COMMON_LOG_DIR="${2}"

				shift 1

				;;

			--zip-list-retention-time)
				ZIP_LIST_RETENTION_TIME="${2}"

				shift 1

				;;

			--version)
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

	process_argument_ignore_zip_files

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
	local release_version="${2}"

	if [ ! -f "${cache_file}" ]
	then
		lc_log ERROR "Cache file '${cache_file}' not found."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local tmp_properties_json="/tmp/${cache_file##*/}"

	if [[ "${release_version}" == 7* ]]
	then

		if (! unzip -p "${cache_file}" fixpack_documentation.json > "${tmp_properties_json}")
		then
			lc_log ERROR "No fixpack_documentation.json file found in '${cache_file}'."

			exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		GIT_REVISION=$(jq -r '.build."git-revision"' "${tmp_properties_json}")
		PATCH_PRODUCT=$(jq -r '.patch."product"' "${tmp_properties_json}")
		PATCH_REQUIREMENTS=$(jq -r '.patch."requirements"' "${tmp_properties_json}")

		if [[ "${PATCH_PRODUCT}" == "7413" ]] && [[ "${PATCH_REQUIREMENTS}" == base-* ]]
		then
			PATCH_REQUIREMENTS="ga1"
		fi

		PRODUCT_VERSION="${release_version}-${PATCH_REQUIREMENTS}"
	else
		if (! unzip -p "${cache_file}" hotfix.json > "${tmp_properties_json}")
		then
			lc_log ERROR "No hotfix.json file found in '${cache_file}'."

			exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		GIT_REVISION=$(jq -r '.build."git-revision"' "${tmp_properties_json}")
		REQUIREMENT_PRODUCT_VERSION=$(jq -r '.requirement."product-version"' "${tmp_properties_json}")

		PRODUCT_VERSION=${REQUIREMENT_PRODUCT_VERSION%.*}
	fi

	lc_log DEBUG "GIT_REVISION: '${GIT_REVISION}'."
	lc_log DEBUG "PRODUCT_VERSION: '${PRODUCT_VERSION}'."

	rm -f "${tmp_properties_json}"
}

function get_hotfix_zip_list_file {
	local release_version="${1}"
	local zip_list_file="${2}"

	local is_new_file

	trap 'clean_up_zip_list_file "${zip_list_file}"' EXIT

	if [ -f "${zip_list_file}" ]
	then
		is_new_file=$(find "${zip_list_file}" -newermt "${ZIP_LIST_RETENTION_TIME} ago")
	fi

	if [ -n "${is_new_file}" ]
	then
		lc_log DEBUG "The file '${zip_list_file}' is new enough, using it."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	else
		lc_log DEBUG "Generating the zip list file: '${zip_list_file}' from '${zip_directory_url}/'."

		if [[ "${release_version}" == 20* ]]
		then
			local zip_directory_name

			for zip_directory_name in $(lc_curl "${zip_directory_url}/" - | grep -E -o "20[0-9]+\.q[0-9]\.[0-9]+" | uniq)
			do
				lc_curl "${zip_directory_url}/${zip_directory_name}/" - | grep -E -o "liferay-dxp-20[a-z0-9\.]+-hotfix-[0-9]{0,9}.zip" | uniq | sed "s@^@${zip_directory_name}/@"
			done > "${zip_list_file}"
		else
			lc_curl "${zip_directory_url}/${zip_directory_name}/" - | grep -E -o "liferay-hotfix-[0-9-]+.zip" | uniq - "${zip_list_file}"
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
	echo "Usage: ${0} [--debug] [--ignore-zip-files <file1,...,fileN>] [--logdir <logdir>] [--zip-list-retention-time '<time>'] [--version <version>] [--no-fetch] [--no-push]"
	echo ""
	echo "    --debug (optional):                                     Enabling debug mode"
	echo "    --ignore-zip-files <file1,...,fileN> (optional):        Comma-separated list of files to be not processed (useful if a file is corrupted on the remote server)"
	echo "    --logdir <logdir> (optional):                           Logging directory, defaults to \"\${PWD}/logs\""
	echo "    --zip-list-retention-time '<time>' (optinal):           Retention time after the update of the zip list is enforced, defaults to '1 min'"
	echo "    --version <version> (optional):                         Version to handle, defaults to \"7.3.10 7.4.13 2023.q3\""
	echo "    --no-fetch (optional):                                  Do not fetch DXP repo"
	echo "    --no-push (optional):                                   Do not push to origin"
	echo ""
	echo "Example (equals to no arguments):"
	echo ""
	echo "${0} --logdir \"\${PWD}/logs\" --zip-list-retention-time '1 min' --version \"7.3.10 7.4.13 2023.q3\""
	echo ""

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function process_argument_ignore_zip_files {

	local ignore_zip_files_persistent_file="$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/ignore_zip_files_persistent.txt"
	local ignore_zip_files_persistent_list=$(tr '\n' ',' < "${ignore_zip_files_persistent_file}")

	IGNORE_ZIP_FILES="${IGNORE_ZIP_FILES},${ignore_zip_files_persistent_list}"
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

		if [[ ${release_version} == 7* ]]
		then
			local zip_directory_url="https://files.liferay.com/private/ee/fix-packs/${release_version}/hotfix"
		else
			local zip_directory_url="https://releases-cdn.liferay.com/dxp/hotfix"
		fi

		lc_time_run get_hotfix_zip_list_file "${release_version}" "${zip_list_file}"

		process_zip_list_file "${zip_list_file}" "${release_version}"
	done
}

function process_zip_list_file {
	local zip_list_file="${1}"
	local release_version="${2}"

	for hotfix_zip_file in $(cat "${zip_list_file}")
	do
		lc_log DEBUG ""

		lc_log DEBUG "Processing ${hotfix_zip_file}."

		local tag_name_new

		tag_name_new="${hotfix_zip_file%.zip}"

		if [[ ${release_version} == 7* ]]
		then
			tag_name_new="${tag_name_new#liferay-}"
		else
			tag_name_new="${tag_name_new#*liferay-dxp-}"
		fi

		check_if_tag_exists liferay-dxp "${tag_name_new}" && continue

		check_ignore_zip_file "${hotfix_zip_file}" "${release_version}" && continue

		file_url="${zip_directory_url}/${hotfix_zip_file}"

		lc_time_run lc_download "${file_url}"

		local cache_file="${LIFERAY_COMMON_DOWNLOAD_CACHE_DIR}/${file_url##*://}"

		lc_time_run get_hotfix_properties "${cache_file}" "${release_version}"

		if [[ ${release_version} == 7* ]]
		then
			check_patch_requirements "${PATCH_REQUIREMENTS}" "${tag_name_new}" || continue
		fi

		copy_hotfix_commit "${GIT_REVISION}" "${PRODUCT_VERSION}" "${tag_name_new}"
	done
}

function clean_up_zip_list_file {
	local zip_list_file="${1}"

	if [ ! -s "${zip_list_file}" ]
	then
		rm -f "${zip_list_file}"
	fi
}

main "${@}"
