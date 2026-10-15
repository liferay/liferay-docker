#!/bin/bash

source ./_test_common.sh

#
# The entrypoint names the configuration fields it supports by hand, so this
# fails when Liferay's schema gains one. It fetches an artifact, as the Tomcat
# version test does, and skips when that is unreachable.
#

function main {
	test_liferay_batch_entrypoint_schema_fields
}

function set_up {
	common_set_up

	_TEST_SCHEMA_DIR=$(mktemp --directory)
}

function tear_down {
	common_tear_down

	rm --force --recursive "${_TEST_SCHEMA_DIR}"

	unset _TEST_SCHEMA_DIR
}

function test_liferay_batch_entrypoint_schema_fields {
	set_up

	local schema_fields=$(_get_schema_fields)

	if [ -z "${schema_fields}" ]
	then
		echo "Unable to read the published schema. Skipping."

		tear_down

		return
	fi

	local expected_schema_fields="callbackURL className companyId fieldNameMappingMap multiCompany parameters taskItemDelegateName userId version"

	assert_equals "${schema_fields}" "${expected_schema_fields}"

	tear_down
}

function _get_schema_fields {
	local version=${LIFERAY_BATCH_ENGINE_API_VERSION:-39.0.0}

	local url="https://repository.liferay.com/nexus/content/groups/public/com/liferay/com.liferay.batch.engine.api/${version}/com.liferay.batch.engine.api-${version}-sources.jar"

	if ! curl \
			--fail \
			--location \
			--max-time 30 \
			--output "${_TEST_SCHEMA_DIR}/sources.jar" \
			--silent \
			"${url}"
	then
		return 0
	fi

	unzip -p "${_TEST_SCHEMA_DIR}/sources.jar" "com/liferay/batch/engine/unit/BatchEngineUnitConfiguration.java" 2> /dev/null | \
		grep --only-matching --perl-regexp '@JsonProperty\("\K[^"]+' | \
		sort | \
		xargs
}

main