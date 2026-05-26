#!/bin/bash

source ../_test_common.sh
source ./crowdin_sync.sh

function main {
	set_up

	test_crowdin_merge_and_commit_translations

	tear_down
}

function set_up {
	export _CROWDIN_DIR="${PWD}"
	export _LIFERAY_PORTAL_REPOSITORY_NAME="liferay-portal"
	export _PROJECTS_DIR=$(mktemp --directory)
	export _TEST_DEPENDENCIES_DIR="${_CROWDIN_DIR}/test-dependencies"

	mkdir "${_PROJECTS_DIR}/${_LIFERAY_PORTAL_REPOSITORY_NAME}"

	lc_cd "${_PROJECTS_DIR}/${_LIFERAY_PORTAL_REPOSITORY_NAME}"

	git init --quiet

	git config user.email "test@test.com"

	git config user.name "Test"

	git commit \
		--allow-empty \
		--message "Initial commit" \
		--quiet
}

function tear_down {
	rm --force --recursive "${_PROJECTS_DIR}"

	unset _CROWDIN_DIR
	unset _LIFERAY_PORTAL_REPOSITORY_NAME
	unset _PROJECTS_DIR
	unset _TEST_DEPENDENCIES_DIR
}

function test_crowdin_merge_and_commit_translations {
	local translation_file="Language_test.properties"

	cp "${_TEST_DEPENDENCIES_DIR}/actual/Language_head.properties" "${translation_file}"

	git add "${translation_file}"

	git commit --message "Baseline for merge_and_commit_translations" --quiet

	cp "${_TEST_DEPENDENCIES_DIR}/actual/Language_crowdin.properties" "${translation_file}"

	merge_and_commit_translations &> /dev/null

	assert_equals "${translation_file}" "${_TEST_DEPENDENCIES_DIR}/expected/Language.properties"
}

main "${@}"
