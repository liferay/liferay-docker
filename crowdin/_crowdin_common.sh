#!/bin/bash

source ../_liferay_common.sh
source ../release/_git.sh

function check_translations_sync {
	local branch=${1}
	local commit_message=${2}
	local repository_name=${3}

	_TRANSLATIONS_SYNCED=false

	lc_cd "${_PROJECTS_DIR}/${repository_name}"

	lc_log INFO "Checking if the latest \"${commit_message}\" commit in brianchandotcom/${repository_name} ${branch} was synced to liferay/${repository_name}."

	if ! git remote get-url brianchandotcom &> /dev/null
	then
		git remote add brianchandotcom git@github.com:brianchandotcom/"${repository_name}".git
	fi

	git fetch --force brianchandotcom "${branch}:refs/remotes/brianchandotcom/${branch}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to fetch ${branch} from brianchandotcom/${repository_name}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ -n "$( \
		git log \
			--format="%H" \
			--grep="${commit_message}" \
			--max-count=1 \
			"${branch}..brianchandotcom/${branch}")" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_TRANSLATIONS_SYNCED=true
}

function filter_translation_files {
	grep --extended-regexp "(Language|bundle)(_[a-zA-Z].*)?\.properties$"
}

function get_changed_translation_files {
	git diff --name-only | filter_translation_files
}

function get_translation_files {
	yq ".files[].source" "${_CROWDIN_DIR}/crowdin.yml" | \
		sed --expression "s#^/##" --expression "s#^#:(glob)#" | \
		xargs --no-run-if-empty git ls-files --
}

function merge_and_commit_translations {
	local commit_message=${1}

	_CREATE_PULL_REQUEST=false

	local changed_files=$(get_changed_translation_files)

	if [ -z "${changed_files}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_log INFO "Merging approved translations into translation files."

	local translation_file

	while IFS= read -r translation_file
	do
		_merge_translation_file "${translation_file}"
	done <<< "${changed_files}"

	local merged_files=$(get_changed_translation_files)

	if [ -z "${merged_files}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_log INFO "Committing $(echo "${merged_files}" | wc --lines) translation files to $(git branch --show-current)."

	commit_changes "${merged_files}" "${commit_message}"

	_CREATE_PULL_REQUEST=true
}

function update_translations_repository {
	local branch=${1}
	local repository_name=${2}

	trap 'return "${LIFERAY_COMMON_EXIT_CODE_BAD}"' ERR

	lc_cd "${_PROJECTS_DIR}/${repository_name}"

	lc_log INFO "Updating ${branch} from liferay/${repository_name} and pushing it to liferay-release/${repository_name}."

	if ! git remote get-url upstream &> /dev/null
	then
		git remote add upstream git@github.com:liferay/"${repository_name}".git
	fi

	git fetch upstream "${branch}:refs/remotes/upstream/${branch}"

	git checkout -B "${branch}" --force "upstream/${branch}"

	git clean -dfx --exclude "tools/gradle-*-bin.zip"

	if ! git remote get-url liferay-release &> /dev/null
	then
		git remote add liferay-release git@github.com:liferay-release/"${repository_name}".git
	fi

	if [ -z "${LIFERAY_RELEASE_TEST_MODE}" ]
	then
		git push liferay-release "${branch}"
	fi

	git log --max-count=1
}

function _apply_translations {
	local head_translation_file=${1}
	local translation_file=${2}

	awk \
		-v head_translation_file="${head_translation_file}" \
		-v translation_file="${translation_file}" '
		function is_translation(line) {
			if (line ~ /^[#!]/ || line !~ /=/) {
				return 0
			}

			return 1
		}

		function parse_key(line) {
			sub(/=.*/, "", line)

			return line
		}

		FILENAME == translation_file {
			if (is_translation($0)) {
				key = parse_key($0)

				translations[key] = $0
			}
		}

		FILENAME == head_translation_file {
			if (!is_translation($0)) {
				print

				next
			}

			key = parse_key($0)

			if (key in translations) {
				print translations[key]
			} else {
				print
			}
		}
	' "${translation_file}" "${head_translation_file}"
}

function _has_new_translations {
	local head_translation_file=${1}
	local merged_translation_file=${2}

	! diff --brief \
		<(grep "=" "${head_translation_file}") \
		<(grep "=" "${merged_translation_file}") &> /dev/null
}

function _merge_translation_file {
	local translation_file=${1}

	local head_translation_file=$(mktemp)

	git show "HEAD:${translation_file}" > "${head_translation_file}"

	local merged_translation_file=$(mktemp)

	_apply_translations "${head_translation_file}" "${translation_file}" > "${merged_translation_file}"

	if [ -n "$(tail --bytes=1 "${head_translation_file}")" ]
	then
		truncate --size=-1 "${merged_translation_file}"
	fi

	if _has_new_translations "${head_translation_file}" "${merged_translation_file}"
	then
		mv "${merged_translation_file}" "${translation_file}"
	else
		cp "${head_translation_file}" "${translation_file}"
	fi

	rm --force "${head_translation_file}" "${merged_translation_file}"
}