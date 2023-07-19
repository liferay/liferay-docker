#!/bin/bash

# shellcheck disable=2002,2013

set -o pipefail

source "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_local_common.sh"

BASE_DIR="${PWD}"

REPO_PATH_DXP="${BASE_DIR}/liferay-dxp"
REPO_PATH_EE="${BASE_DIR}/liferay-portal-ee"

TAGS_FILE_DXP="/tmp/tags_file_dxp.txt"
TAGS_FILE_EE="/tmp/tags_file_ee.txt"
TAGS_FILE_NEW="/tmp/tags_file_new.txt"

function check_new_tags {
	if [ ! -f "${TAGS_FILE_NEW}" ]
	then
		echo "No new tags found."

		exit 0
	fi
}

function check_usage {
	LIFERAY_COMMON_DEBUG_ENABLED="no"
	LIFERAY_COMMON_LOG_DIR="${PWD}/logs"
	RUN_FETCH_REPOSITORY="yes"
	RUN_PUSH_TO_ORIGIN="yes"
	VERSION_INPUT="7.[0-9].[0-9] 7.[0-9].1[0-9]"

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

function checkout_branch {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	local branch_name="${2}"

	lc_cd "${BASE_DIR}/${1}"

	git reset --hard
	git clean -fdX

	if (git show-ref --quiet "${branch_name}")
	then
		git checkout -f -q "${branch_name}"

		if [ "${RUN_FETCH_REPOSITORY}" == "yes" ]
		then
			git pull origin "${branch_name}"
		fi
	else
		git branch "${branch_name}"
		git checkout -f -q "${branch_name}"
	fi
}

function get_all_tags {
	git tag -l --sort=creatordate --format='%(refname:short)' "${VERSION_LIST[@]}"
}

function get_new_tags {
	lc_cd "${REPO_PATH_EE}"

	get_all_tags > "${TAGS_FILE_EE}"

	lc_cd "${REPO_PATH_DXP}"

	get_all_tags > "${TAGS_FILE_DXP}"

	local tag_name

	rm -f "${TAGS_FILE_NEW}"

	# shellcheck disable=SC2013
	for tag_name in $(cat "${TAGS_FILE_EE}")
	do
		if (! grep -qw "${tag_name}" "${TAGS_FILE_DXP}")
		then
			echo "${tag_name}" >> "${TAGS_FILE_NEW}"
		fi
	done
}

function copy_tag {
	local tag_name="${1}"

	lc_time_run checkout_tag_simple liferay-portal-ee "${tag_name}"

	lc_cd "${REPO_PATH_DXP}"

	lc_time_run run_git_maintenance

	lc_time_run run_rsync "${tag_name}"

	lc_time_run commit_and_tag "${tag_name}"
}

function print_help {
	echo ""
	echo "Usage:"
	echo ""
	echo "${0} [-l|--logdir <logdir>] [-v|--version <version>] [--no-fetch] [--no-push]"
	echo ""
	echo "    -d|--debug (optional):                Enabling debug mode"
	echo "    -l|--logdir <logdir> (optional):      Logging directory, defaults to \"\${PWD}/logs\""
	echo "    -v|--version <version> (optional):    Version to handle, defaults to \"7.[0-9].1[03]\""
	echo "    --no-fetch (optional):                Do not fetch DXP repo"
	echo "    --no-push (optional):                 Do not push to origin"
	echo ""
	echo "Default (equal to no arguments):"
	echo ""
	echo "${0} -l \"\$PWD/logs\" -v \"7.[0-9].[0-9] 7.[0-9].1[0-9]\""
	echo ""

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function process_argument_version {
	local IFS=" "

	read -r -a VERSION_ARRAY <<< "${VERSION_INPUT}"

	VERSION_LIST=("${VERSION_ARRAY[@]/%/-ga[0-9]*}" "${VERSION_ARRAY[@]/%/-u[0-9]*}")
}

function main {
	check_usage "${@}"

	process_argument_version

	lc_time_run clone_repository liferay-dxp

	lc_time_run clone_repository liferay-portal-ee

	lc_time_run fetch_repository liferay-dxp

	lc_time_run fetch_repository liferay-portal-ee

	lc_time_run get_new_tags

	check_new_tags

	for branch in $(cat "${TAGS_FILE_NEW}" | sed -e "s/-.*//" | sort -nu)
	do
		for update in $(cat "${TAGS_FILE_NEW}" | grep "^${branch}" | sed -e "s/.*-//")
		do
			echo ""
			echo "Processing: ${branch}-${update}"
			lc_time_run checkout_branch liferay-dxp "${branch}"

			copy_tag "${branch}-${update}"

			lc_time_run push_to_origin "${branch}-${update}"

			lc_time_run push_to_origin "${branch}"
		done
	done
}

main "${@}"