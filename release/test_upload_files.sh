#!/bin/bash

source ../_test_common.sh
source ./upload_files.sh

function main {
	test_upload_files_is_valid_upload_destination_dir_name
	test_upload_files_is_valid_upload_source_dir
}

function test_upload_files_is_valid_upload_destination_dir_name {
	_test_upload_files_is_valid_upload_destination_dir_name "" "1"
	_test_upload_files_is_valid_upload_destination_dir_name ".." "1"
	_test_upload_files_is_valid_upload_destination_dir_name "3.10.0-ga1" "0"
	_test_upload_files_is_valid_upload_destination_dir_name "4.0.1 GA" "1"
	_test_upload_files_is_valid_upload_destination_dir_name "4.0.1" "0"
	_test_upload_files_is_valid_upload_destination_dir_name "\"4.0.1\"" "1"
	_test_upload_files_is_valid_upload_destination_dir_name "gs://liferay-releases/tools/ide/4.0.1" "1"
	_test_upload_files_is_valid_upload_destination_dir_name "~" "1"
}

function test_upload_files_is_valid_upload_source_dir {
	_test_upload_files_is_valid_upload_source_dir "" "1"
	_test_upload_files_is_valid_upload_source_dir "../../../root/.ssh" "1"
	_test_upload_files_is_valid_upload_source_dir "/root/.ssh" "1"
	_test_upload_files_is_valid_upload_source_dir "4.x/../../../root" "1"
	_test_upload_files_is_valid_upload_source_dir "4.x//202608072258" "1"
	_test_upload_files_is_valid_upload_source_dir "4.x/2026 0807" "1"
	_test_upload_files_is_valid_upload_source_dir "4.x/202608072258" "0"
	_test_upload_files_is_valid_upload_source_dir "4.x/202608072258/" "1"
	_test_upload_files_is_valid_upload_source_dir "~/.ssh" "1"
}

function _test_upload_files_is_valid_upload_destination_dir_name {
	_is_valid_upload_destination_dir_name "${1}"

	assert_equals "${?}" "${2}"
}

function _test_upload_files_is_valid_upload_source_dir {
	_is_valid_upload_source_dir "${1}"

	assert_equals "${?}" "${2}"
}

main