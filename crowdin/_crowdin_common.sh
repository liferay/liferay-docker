#!/bin/bash

source ../_liferay_common.sh
source ../release/_git.sh

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

	commit_changes "${merged_files}" "${commit_message}"

	_CREATE_PULL_REQUEST=true
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