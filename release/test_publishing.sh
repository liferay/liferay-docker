#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source _publishing.sh

function main {
	setup

	_update_bundles_yml &> /dev/null

	_PRODUCT_VERSION="7.4.13-u130"

	_update_bundles_yml &> /dev/null

	_PRODUCT_VERSION="2024.q3.1"

	_update_bundles_yml &> /dev/null

	test_update_bundles_yml

	tear_down
}

function setup {
	export _PRODUCT_VERSION="7.4.3.125-ga125"
	export _RELEASE_ROOT_DIR="${PWD}"

	export _BASE_DIR="${_RELEASE_ROOT_DIR}/test-dependencies"
}

function tear_down {
	git reset HEAD~3 --hard &> /dev/null

	unset _BASE_DIR
	unset _PRODUCT_VERSION
	unset _RELEASE_ROOT_DIR
}

function test_update_bundles_yml {
	assert_equals "${_BASE_DIR}/bundles.yml" "${_BASE_DIR}/expected.bundles.yml"
}

main