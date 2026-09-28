#!/bin/bash

source ../_gh_pr.sh
source ../_liferay_common.sh
source ../release/_git.sh
source ./_crowdin_common.sh

function check_usage {
	_CROWDIN_DIR=${PWD}

	LIFERAY_COMMON_LOG_DIR="${_CROWDIN_DIR}/logs"

	_PROJECTS_DIR="/opt/dev/projects/github"

	if [ ! -d "${_PROJECTS_DIR}" ]
	then
		_PROJECTS_DIR=${_CROWDIN_DIR}
	fi
}

function export_master_translations {
	local release_branch=${1}

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	lc_log INFO "Exporting the translations from master that can be backported to ${release_branch}."

	local source_file

	for source_file in $(get_translation_files)
	do
		lc_log INFO "Exporting the translations of ${source_file}."

		local translation_file

		for translation_file in $(git ls-files ":(glob)$(dirname "${source_file}")/$(basename "${source_file}" ".properties")_*.properties")
		do
			_get_master_translations "${source_file}" "${translation_file}" > "${translation_file}"
		done
	done
}

function fetch_upstream_master {
	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	lc_log INFO "Fetching master from liferay/liferay-portal-ee."

	if ! git remote get-url upstream &> /dev/null
	then
		git remote add upstream git@github.com:liferay/liferay-portal-ee.git
	fi

	git fetch upstream "master:refs/remotes/upstream/master"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to fetch master from liferay/liferay-portal-ee."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_usage

	if [ "${_PROJECTS_DIR}" == "${_CROWDIN_DIR}" ]
	then
		lc_background_run clone_repository liferay-portal-ee

		lc_wait
	fi

	lc_time_run fetch_upstream_master

	lc_time_run set_supported_release_branches

	lc_log INFO "Backporting translations to the supported release branches: ${_SUPPORTED_RELEASE_BRANCHES[*]}."

	_backport_translations
}

function set_supported_release_branches {
	_SUPPORTED_RELEASE_BRANCHES=()

	local releases_json_dir=$(mktemp --directory)
	local releases_json_url="https://releases.liferay.com/releases.json"

	lc_log INFO "Downloading ${releases_json_url} to find the supported release branches."

	LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true" lc_download "${releases_json_url}" "${releases_json_dir}/releases.json"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to download ${releases_json_url}."

		rm --force --recursive "${releases_json_dir}"

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local release_branch

	for release_branch in $(_get_supported_release_branches "${releases_json_dir}/releases.json")
	do
		lc_log INFO "Found the supported release branch ${release_branch} in releases.json."

		_SUPPORTED_RELEASE_BRANCHES+=("${release_branch}")
	done

	rm --force --recursive "${releases_json_dir}"

	if [[ "${#_SUPPORTED_RELEASE_BRANCHES[@]}" -eq 0 ]]
	then
		lc_log ERROR "Unable to find a supported release branch in ${releases_json_url}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function set_up_branch {
	local release_branch=${1}

	_TEMP_BRANCH="backport-translations-${release_branch}-$(date "+%Y%m%d%H%M%S")"

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	lc_log INFO "Creating branch ${_TEMP_BRANCH} from ${release_branch}."

	git checkout -b "${_TEMP_BRANCH}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to create branch ${_TEMP_BRANCH}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _backport_translations {
	local release_branch

	for release_branch in "${_SUPPORTED_RELEASE_BRANCHES[@]}"
	do
		lc_log INFO "Backporting translations from master to ${release_branch}."

		lc_time_run close_pull_request \
			"head:backport-translations-${release_branch}" \
			"liferay-release/liferay-portal-ee"

		lc_time_run update_translations_repository "${release_branch}" "liferay-portal-ee"

		lc_time_run check_translations_sync \
			"${release_branch}" \
			"LPD-105062 Backport Translations" \
			"liferay-portal-ee"

		if [ "${_TRANSLATIONS_SYNCED}" != "true" ]
		then
			lc_log INFO "Skipping ${release_branch} because the latest translations backport was not synced to liferay/liferay-portal-ee."

			continue
		fi

		lc_time_run set_up_branch "${release_branch}"

		lc_time_run export_master_translations "${release_branch}"

		lc_time_run merge_and_commit_translations "LPD-105062 Backport Translations"

		if [ "${_CREATE_PULL_REQUEST}" != "true" ]
		then
			lc_log INFO "Skipping pull request creation for ${release_branch} because there are no new translations."

			continue
		fi

		lc_time_run push_branch_to_liferay_release_fork \
			"${_TEMP_BRANCH}" \
			"liferay-portal-ee"

		lc_time_run create_pull_request \
			"${release_branch}" \
			"${_TEMP_BRANCH}" \
			"liferay-release/liferay-portal-ee" \
			"LPD-105062 Backport Translations | ${release_branch}"

		lc_log INFO "Created pull request for ${release_branch}."
	done
}

function _get_master_translations {
	local source_file=${1}
	local translation_file=${2}

	awk '
		FILENAME == ARGV[1] {
			source_lines[$0]

			next
		}

		FILENAME == ARGV[2] {
			if ($0 in source_lines) {
				sub(/=.*/, "")

				unchanged_keys[$0]
			}

			next
		}

		/=/ && !/^[#!]/ && !/\(Automatic Copy\)$/ {
			key = $0

			sub(/=.*/, "", key)

			if (key in unchanged_keys) {
				print
			}
		}
	' "${source_file}" <(git show "upstream/master:${source_file}" 2> /dev/null) <(git show "upstream/master:${translation_file}" 2> /dev/null)
}

function _get_supported_release_branches {
	jq --raw-output ".[] | select(.product == \"dxp\" and ((.tags // []) | index(\"supported\"))) | .productGroupVersion" "${1}" | \
		grep --extended-regexp "^[0-9]{4}\.q[1-4]$" | \
		sort --unique | \
		sed --expression "s/^/release-/"
}

main "${@}"
