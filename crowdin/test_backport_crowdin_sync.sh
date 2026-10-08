#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./backport_crowdin_sync.sh

function main {
	set_up

	if [[ "${#}" -eq 1 ]]
	then
		"${1}"
	else
		test_backport_crowdin_sync_export_master_translations
		test_backport_crowdin_sync_get_supported_release_branches
		test_backport_crowdin_sync_not_export_master_translations
	fi

	tear_down
}

function set_up {
	common_set_up

	export _CROWDIN_DIR=${PWD}
	export _PROJECTS_DIR=$(mktemp --directory)
}

function tear_down {
	common_tear_down

	lc_cd "${_CROWDIN_DIR}"

	rm --force --recursive "${_PROJECTS_DIR}"

	unset _CROWDIN_DIR
	unset _PROJECTS_DIR
}

function test_backport_crowdin_sync_export_master_translations {
	_test_backport_crowdin_sync_export_master_translations \
		"modules/apps/portal-language/portal-language-lang/src/main/resources/content" \
		"Language"
	_test_backport_crowdin_sync_export_master_translations \
		"modules/apps/test/app.bnd-localization" \
		"bundle"
}

function test_backport_crowdin_sync_get_supported_release_branches {
	cat <<- END > "${_PROJECTS_DIR}/releases.json"
	[
		{"product": "dxp", "productGroupVersion": "2024.q1", "tags": ["supported", "testBom"]},
		{"product": "dxp", "productGroupVersion": "2025.q1", "tags": ["supported"]},
		{"product": "dxp", "productGroupVersion": "2025.q1", "tags": ["recommended", "supported"]},
		{"product": "dxp", "productGroupVersion": "2025.q2", "tags": ["recommended"]},
		{"product": "dxp", "productGroupVersion": "2026.q1"},
		{"product": "dxp", "productGroupVersion": "7.4", "tags": ["supported"]},
		{"product": "portal", "productGroupVersion": "2026.q2", "tags": ["supported"]}
	]
	END

	assert_equals \
		"$(_get_supported_release_branches "${_PROJECTS_DIR}/releases.json")" \
		"release-2024.q1
release-2025.q1"

	rm --force "${_PROJECTS_DIR}/releases.json"
}

function test_backport_crowdin_sync_not_export_master_translations {
	local translation_dir="modules/apps/portal-language/portal-language-lang/src/main/resources/content"

	_set_up_translation_files "Branch translation" "${translation_dir}" "Language"

	export_master_translations "release-test" &> /dev/null

	merge_and_commit_translations "LPD-105062 Backport Translations" &> /dev/null

	assert_equals "$(git log --format="%s" --max-count=1)" "Release branch"
}

function _set_up_translation_files {
	local master_copied_translation=${1}
	local translation_dir=${2}
	local translation_file_prefix=${3}

	rm --force --recursive "${_PROJECTS_DIR}/liferay-portal-ee"

	mkdir --parents "${_PROJECTS_DIR}/liferay-portal-ee/${translation_dir}"

	lc_cd "${_PROJECTS_DIR}/liferay-portal-ee"

	git init --quiet

	cat <<- END > "${translation_dir}/${translation_file_prefix}.properties"
	key-automatic-copy=Automatic Copy
	key-copied=Copied
	key-english-changed=Master English
	key-master-only=Master Only
	key-unchanged=Unchanged
	END

	cat <<- END > "${translation_dir}/${translation_file_prefix}_pt_BR.properties"
	key-automatic-copy=Automatic Copy (Automatic Copy)
	key-copied=${master_copied_translation}
	key-english-changed=Master translation
	key-master-only=Master translation
	key-unchanged=Same translation
	END

	git add "${translation_dir}"

	git commit --message "Master" --quiet

	git update-ref refs/remotes/upstream/master HEAD

	cat <<- END > "${translation_dir}/${translation_file_prefix}.properties"
	key-automatic-copy=Automatic Copy
	key-branch-only=Branch Only
	key-copied=Copied
	key-english-changed=Branch English
	key-unchanged=Unchanged
	END

	cat <<- END > "${translation_dir}/${translation_file_prefix}_pt_BR.properties"
	key-automatic-copy=Branch translation
	key-branch-only=Branch translation
	key-copied=Branch translation
	key-english-changed=Branch translation
	key-unchanged=Same translation
	END

	git add "${translation_dir}"

	git commit --message "Release branch" --quiet
}

function _test_backport_crowdin_sync_export_master_translations {
	local translation_dir=${1}
	local translation_file_prefix=${2}

	_set_up_translation_files "Master translation" "${translation_dir}" "${translation_file_prefix}"

	export_master_translations "release-test" &> /dev/null

	merge_and_commit_translations "LPD-105062 Backport Translations" &> /dev/null

	cat <<- END > "${_PROJECTS_DIR}/expected.properties"
	key-automatic-copy=Branch translation
	key-branch-only=Branch translation
	key-copied=Master translation
	key-english-changed=Branch translation
	key-unchanged=Same translation
	END

	assert_equals \
		"${translation_dir}/${translation_file_prefix}_pt_BR.properties" \
		"${_PROJECTS_DIR}/expected.properties"

	rm --force "${_PROJECTS_DIR}/expected.properties"
}

main "${@}"