#!/bin/bash

source ../_gh_pr.sh
source ../_liferay_common.sh
source ../release/_git.sh

function check_translations_sync {
	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	if ! git remote get-url brianchandotcom &> /dev/null
	then
		git remote add brianchandotcom "git@github.com:brianchandotcom/liferay-portal.git"
	fi

	git fetch --force brianchandotcom "master:refs/remotes/brianchandotcom/master"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to fetch master from brianchandotcom/liferay-portal."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ -n "$( \
		git log \
			-1 \
			--format="%H" \
			--grep="LPD-91206 Update Translations" \
			master..brianchandotcom/master)" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	_TRANSLATIONS_SYNCED=true
}

function check_usage {
	if [ -z "${CROWDIN_API_TOKEN}" ] ||
	   [ -z "${CROWDIN_PROJECT_ID}" ]
	then
		print_help
	fi

	_CROWDIN_DIR=${PWD}

	LIFERAY_COMMON_LOG_DIR="${_CROWDIN_DIR}/logs"

	_LANG_BUILDER_LIB_DIR="tools/sdk/dependencies/com.liferay.lang.builder/lib"

	_PROJECTS_DIR="/opt/dev/projects/github"

	if [ ! -d "${_PROJECTS_DIR}" ]
	then
		_PROJECTS_DIR=${_CROWDIN_DIR}
	fi

	_TRANSLATION_FILE_REGEX="(Language|bundle)(_[a-zA-Z].*)?\.properties$"
}

function download_translations {
	lc_log INFO "Downloading translations from Crowdin."

	crowdin download translations \
		--branch "master" \
		--export-only-approved \
		--no-progress \
		--plain \
		--verbose

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to download translations from Crowdin."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	check_usage

	lc_time_run close_pull_request \
		"head:crowdin-translations" \
		"liferay-release/liferay-portal"

	if [ "${_PROJECTS_DIR}" == "${_CROWDIN_DIR}" ]
	then
		lc_background_run clone_repository liferay-portal

		lc_wait
	fi

	lc_time_run update_portal_repository

	lc_time_run check_translations_sync

	if [ "${_TRANSLATIONS_SYNCED}" != "true" ]
	then
		lc_log INFO "Skipping the Crowdin synchronization because the latest translations commit was not synced to liferay/liferay-portal."

		exit "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	lc_time_run set_up_branch

	lc_time_run set_up_lang_builder

	lc_time_run normalize_existing_translations

	lc_time_run upload_sources

	lc_time_run download_translations

	lc_time_run merge_and_commit_translations

	if [ "${_CREATE_PULL_REQUEST}" != "true" ]
	then
		lc_log INFO "Skipping pull request creation because there are no new translations."

		exit "${LIFERAY_COMMON_EXIT_CODE_OK}"
	fi

	lc_time_run normalize_synced_translations

	lc_time_run push_branch_to_liferay_release_fork \
		"${_TEMP_BRANCH}" \
		"liferay-portal"

	lc_time_run create_pull_request \
		"master" \
		"${_TEMP_BRANCH}" \
		"liferay-release/liferay-portal" \
		"LPD-91206 Update Translations"
}

function merge_and_commit_translations {
	local changed_files=$(_get_changed_files)

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

	local merged_files=$(_get_changed_files)

	if [ -z "${merged_files}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	commit_changes "${merged_files}" "LPD-91206 Update Translations"

	_CREATE_PULL_REQUEST=true
}

function normalize_existing_translations {
	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	lc_log INFO "Running Lang Builder to normalize the existing translations."

	local translation_files=$( \
		yq ".files[].source" "${_CROWDIN_DIR}/crowdin.yml" | \
		sed --expression "s#^/##" --expression "s#^#:(glob)#" | \
		xargs --no-run-if-empty git ls-files --)

	_run_lang_builder_on_files "${translation_files}"

	if [[ "${?}" -ne 0 ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local normalized_translation_files=$(_get_changed_files)

	if [ -z "${normalized_translation_files}" ]
	then
		lc_log INFO "Skipping the buildLang commit because Lang Builder made no changes to the existing translations."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	commit_changes "${normalized_translation_files}" "LPD-91206 buildLang"
}

function normalize_synced_translations {
	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	local changed_translation_files=$( \
		git show --name-only --pretty=format: HEAD | grep --extended-regexp "${_TRANSLATION_FILE_REGEX}")

	if [ -z "${changed_translation_files}" ]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_log INFO "Running Lang Builder to normalize the synced translations."

	_run_lang_builder_on_files "${changed_translation_files}"

	if [[ "${?}" -ne 0 ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local normalized_translation_files=$(_get_changed_files)

	if [ -z "${normalized_translation_files}" ]
	then
		lc_log INFO "Skipping the Crowdin translation update because Lang Builder made no changes to the synced translations."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	local branch_id=$(_get_crowdin_branch_id)

	if [ -z "${branch_id}" ]
	then
		lc_log ERROR "Unable to get the Crowdin branch ID for the master branch."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local normalized_translation_file

	while IFS= read -r normalized_translation_file
	do
		_push_normalized_translations "${branch_id}" "${normalized_translation_file}"

		git add "${normalized_translation_file}"
	done <<< "${normalized_translation_files}"

	git commit --amend --no-edit
}

function print_help {
	echo "Usage: ${0}"
	echo ""
	echo "The script reads the following environment variables:"
	echo ""
	echo "    CROWDIN_API_TOKEN: Crowdin API token."
	echo "    CROWDIN_PROJECT_ID: Crowdin project ID."
	echo ""

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function set_up_branch {
	_TEMP_BRANCH="crowdin-translations-$(date "+%Y%m%d%H%M%S")"

	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	git checkout -b "${_TEMP_BRANCH}"

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to create branch ${_TEMP_BRANCH}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	cp "${_CROWDIN_DIR}/crowdin.yml" "${_PROJECTS_DIR}/liferay-portal"
}

function set_up_lang_builder {
	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	lc_log INFO "Setting up the SDK to install Lang Builder."

	ant setup-sdk

	if [ ! -d "${_LANG_BUILDER_LIB_DIR}" ]
	then
		lc_log ERROR "Unable to set up Lang Builder."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function update_portal_repository {
	trap "return ${LIFERAY_COMMON_EXIT_CODE_BAD}" ERR

	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	git checkout master --force

	git clean -dfx --exclude "tools/gradle-*-bin.zip"

	if ! git remote get-url upstream &> /dev/null
	then
		git remote add upstream "git@github.com:liferay/liferay-portal.git"
	fi

	git fetch upstream "master:refs/remotes/upstream/master"

	git reset --hard upstream/master

	if ! git remote get-url liferay-release &> /dev/null
	then
		git remote add liferay-release "git@github.com:liferay-release/liferay-portal.git"
	fi

	git push liferay-release master

	git log -1
}

function upload_sources {
	lc_log INFO "Uploading source files to Crowdin."

	crowdin upload sources \
		--branch "master" \
		--no-progress \
		--plain \
		--verbose

	if [[ "${?}" -ne 0 ]]
	then
		lc_log ERROR "Unable to upload source files to Crowdin."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _apply_crowdin_translations {
	local crowdin_translation_file=${1}
	local head_translation_file=${2}

	awk \
		-v crowdin_translation_file="${crowdin_translation_file}" \
		-v head_translation_file="${head_translation_file}" '
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

		FILENAME == crowdin_translation_file {
			if (is_translation($0)) {
				key = parse_key($0)

				crowdin_translations[key] = $0
			}
		}

		FILENAME == head_translation_file {
			if (!is_translation($0)) {
				print

				next
			}

			key = parse_key($0)

			if (key in crowdin_translations) {
				print crowdin_translations[key]
			} else {
				print
			}
		}
	' "${crowdin_translation_file}" "${head_translation_file}"
}

function _get_changed_files {
	git diff --name-only | grep --extended-regexp "${_TRANSLATION_FILE_REGEX}"
}

function _get_crowdin_branch_id {
	local response=$( \
		_get_crowdin_data \
			"projects/${CROWDIN_PROJECT_ID}/branches" \
			"name=master")

	if [ -z "${response}" ]
	then
		return
	fi

	echo "${response}" | jq --raw-output ".data[0].data.id"
}

function _get_crowdin_data {
	local api_path=${1}

	shift

	local query_arguments=()

	local query_parameter

	for query_parameter in "${@}"
	do
		query_arguments+=(--data-urlencode "${query_parameter}")
	done

	local http_code_file=$(mktemp)

	local response=$( \
		curl \
			--connect-timeout 10 \
			--get \
			--header "Authorization: Bearer ${CROWDIN_API_TOKEN}" \
			--max-time 30 \
			--retry 5 \
			--retry-connrefused \
			--retry-max-time 60 \
			--show-error \
			--silent \
			--write-out "%output{${http_code_file}}%{http_code}" \
			"${query_arguments[@]}" \
			"https://api.crowdin.com/api/v2/${api_path}")

	local http_code=$(cat "${http_code_file}")

	rm --force "${http_code_file}"

	if [[ "${http_code}" -ge 400 ]]
	then
		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	echo "${response}"
}

function _get_crowdin_string_id {
	local branch_id=${1}
	local key=${2}

	local response=$( \
		_get_crowdin_data \
			"projects/${CROWDIN_PROJECT_ID}/strings" \
			"branchId=${branch_id}" \
			"filter=${key}" \
			"limit=500" \
			"scope=identifier")

	if [ -z "${response}" ]
	then
		return
	fi

	echo "${response}" | jq --raw-output ".data[] | select(.data.identifier == \"${key}\") | .data.id // empty"
}

function _get_crowdin_translation_id {
	local crowdin_language_id=${1}
	local string_id=${2}
	local text=${3}

	local response=$( \
		_get_crowdin_data \
			"projects/${CROWDIN_PROJECT_ID}/translations" \
			"languageId=${crowdin_language_id}" \
			"limit=100" \
			"stringId=${string_id}")

	if [ -z "${response}" ]
	then
		return
	fi

	local translation

	while IFS= read -r translation
	do
		if [ "$(echo "${translation}" | jq --raw-output ".data.text")" == "${text}" ]
		then
			echo "${translation}" | jq --raw-output ".data.id // empty"

			return
		fi
	done <<< "$(echo "${response}" | jq --compact-output ".data[]")"
}

function _has_new_translations {
	local head_translation_file=${1}
	local merged_translation_file=${2}

	! diff --brief \
		<(grep "=" "${head_translation_file}") \
		<(grep "=" "${merged_translation_file}") &> /dev/null
}

function _merge_translation_file {
	local crowdin_translation_file=${1}

	local head_translation_file=$(mktemp)

	git show "HEAD:${crowdin_translation_file}" > "${head_translation_file}"

	local merged_translation_file=$(mktemp)

	_apply_crowdin_translations "${crowdin_translation_file}" "${head_translation_file}" > "${merged_translation_file}"

	if [ -n "$(tail --bytes=1 "${head_translation_file}")" ]
	then
		truncate --size=-1 "${merged_translation_file}"
	fi

	if _has_new_translations "${head_translation_file}" "${merged_translation_file}"
	then
		mv "${merged_translation_file}" "${crowdin_translation_file}"
	else
		cp "${head_translation_file}" "${crowdin_translation_file}"
	fi

	rm --force "${head_translation_file}" "${merged_translation_file}"
}

function _post_crowdin_data {
	local api_path=${1}
	local data=${2}

	curl \
		--connect-timeout 10 \
		--data "${data}" \
		--header "Authorization: Bearer ${CROWDIN_API_TOKEN}" \
		--header "Content-Type: application/json" \
		--max-time 30 \
		--request POST \
		--retry 5 \
		--retry-connrefused \
		--retry-max-time 60 \
		--show-error \
		--silent \
		"https://api.crowdin.com/api/v2/${api_path}"
}

function _push_normalized_translations {
	local branch_id=${1}
	local translation_file=${2}

	local translation_file_name=$(basename "${translation_file}")

	local locale=$( \
		echo "${translation_file_name}" | sed --regexp-extended --expression "s/^(Language|bundle)_(.+)\.properties$/\2/")

	if [ "${locale}" == "${translation_file_name}" ]
	then
		return
	fi

	local crowdin_language_id=$(yq ".files[0].languages_mapping.locale | to_entries[] | select(.value == \"${locale}\") | .key" "${_CROWDIN_DIR}/crowdin.yml")

	if [ -z "${crowdin_language_id}" ]
	then
		lc_log INFO "Skipping locale ${locale} because it is not a mapped Crowdin target language."

		return
	fi

	local head_translation_file=$(mktemp)

	git show "HEAD:${translation_file}" > "${head_translation_file}"

	local normalized_translations=$( \
		diff "${head_translation_file}" "${translation_file}" | \
		grep "^>" | \
		sed --expression "s/^> //")

	local normalized_translation

	while IFS= read -r normalized_translation
	do
		if [ -z "${normalized_translation}" ]
		then
			continue
		fi

		local key=$(echo "${normalized_translation}" | sed --expression "s/=.*//")

		local string_id=$(_get_crowdin_string_id "${branch_id}" "${key}")

		if [ -z "${string_id}" ]
		then
			lc_log WARN "Unable to find a Crowdin string for key ${key}."

			continue
		fi

		local text=$(echo "${normalized_translation}" | sed --expression "s/^[^=]*=//")

		_update_crowdin_translation "${crowdin_language_id}" "${key}" "${string_id}" "${text}"
	done <<< "${normalized_translations}"

	rm --force "${head_translation_file}"
}

function _run_lang_builder_on_files {
	local translation_files=${1}

	lc_cd "${_PROJECTS_DIR}/liferay-portal"

	local translation_dirs=$( \
		echo "${translation_files}" | \
		xargs dirname | \
		sort --unique)

	local translation_dir

	while IFS= read -r translation_dir
	do
		local translation_file_prefix="Language"

		if [ "$(basename "${translation_dir}")" == "app.bnd-localization" ]
		then
			translation_file_prefix="bundle"
		fi

		java \
			-Dfile.encoding=UTF-8 \
			-Duser.country=US \
			-Duser.language=en \
			-classpath "${_LANG_BUILDER_LIB_DIR}/*" \
			com.liferay.lang.builder.LangBuilder \
			"lang.dir=${translation_dir}" \
			"lang.file=${translation_file_prefix}" \
			"lang.translate=false"

		if [[ "${?}" -ne 0 ]]
		then
			lc_log ERROR "Unable to run Lang Builder in ${translation_dir}."

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi

		local translation_file

		for translation_file in "${translation_dir}/${translation_file_prefix}"*.properties
		do
			if [ -z "$(git show "HEAD:${translation_file}" 2> /dev/null | tail --bytes=1)" ] &&
			   [ -n "$(tail --bytes=1 "${translation_file}")" ]
			then
				printf "\n" >> "${translation_file}"
			fi
		done
	done <<< "${translation_dirs}"
}

function _update_crowdin_translation {
	local crowdin_language_id=${1}
	local key=${2}
	local string_id=${3}
	local text=${4}

	local translation_data=$(
		cat <<- END
		{
			"languageId": "${crowdin_language_id}",
			"stringId": ${string_id},
			"text": $(printf "%s" "${text}" | jq --raw-input --slurp ".")
		}
		END
	)

	local translation_response=$( \
		_post_crowdin_data \
			"projects/${CROWDIN_PROJECT_ID}/translations" \
			"${translation_data}")

	local translation_id=$(echo "${translation_response}" | jq --raw-output ".data.id // empty")

	if [ -z "${translation_id}" ]
	then
		translation_id=$(_get_crowdin_translation_id "${crowdin_language_id}" "${string_id}" "${text}")
	fi

	if [ -z "${translation_id}" ]
	then
		local error_message=$( \
			echo "${translation_response}" | jq --raw-output "[.errors[]?.error.errors[]?.message] | join(\", \")")

		lc_log WARN "Unable to update the Crowdin translation for ${key} in ${crowdin_language_id}. Crowdin returned \"${error_message}\"."

		return
	fi

	local approval_data=$(
		cat <<- END
		{
			"translationId": ${translation_id}
		}
		END
	)

	local approval_response=$( \
		_post_crowdin_data \
			"projects/${CROWDIN_PROJECT_ID}/approvals" \
			"${approval_data}")

	if [ -z "$(echo "${approval_response}" | jq --raw-output ".data.id // empty")" ]
	then
		local error_message=$( \
			echo "${approval_response}" | jq --raw-output "[.errors[]?.error.errors[]?.message] | join(\", \")")

		lc_log WARN "Unable to approve the Crowdin translation for ${key} in ${crowdin_language_id}. Crowdin returned \"${error_message}\"."

		return
	fi

	lc_log INFO "Updated the Crowdin translation for ${key} in ${crowdin_language_id}."
}

main "${@}"