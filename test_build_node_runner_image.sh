#!/bin/bash

source ./_liferay_common.sh
source ./_test_common.sh

function main {
	set_up

	if [[ "${#}" -eq 1 ]]
	then
		"${1}"
	else
		test_build_node_runner_image_derived_image_installs_dependencies
		test_build_node_runner_image_entrypoint_passes_arguments
		test_build_node_runner_image_entrypoint_starts_default_command
		test_build_node_runner_image_has_node_on_path
		test_build_node_runner_image_switches_node_version
	fi

	tear_down
}

function set_up {
	export _TEST_DERIVED_IMAGE="liferay/node-runner-derived:test"
	export _TEST_NODE_RUNNER_IMAGE="liferay/node-runner:test"

	docker build \
		--tag "${_TEST_NODE_RUNNER_IMAGE}" \
		templates/node-runner &> /dev/null

	export _TEST_APP_DIR=$(mktemp --directory)

	echo 'console.log("[LIFERAY_NODE_RUNNER_TEST] started");' > "${_TEST_APP_DIR}/app.js"

	cat <<- EOF > "${_TEST_APP_DIR}/package.json"
	{
		"dependencies": {
			"left-pad": "1.3.0"
		},
		"name": "liferay-node-runner-test",
		"scripts": {
			"start": "node app.js"
		},
		"version": "1.0.0"
	}
	EOF

	#
	# A Client Extension is built from a derived image, so "npm install" has to
	# work in a "RUN" layer. See LPD-98466 and PTR-9125.
	#

	cat <<- EOF > "${_TEST_APP_DIR}/Dockerfile"
	FROM ${_TEST_NODE_RUNNER_IMAGE}

	COPY --chown=liferay:liferay app.js package.json ./

	RUN npm install --no-workspaces
	EOF

	docker build \
		--tag "${_TEST_DERIVED_IMAGE}" \
		"${_TEST_APP_DIR}" &> /dev/null
}

function tear_down {
	docker rmi --force "${_TEST_DERIVED_IMAGE}" &> /dev/null
	docker rmi --force "${_TEST_NODE_RUNNER_IMAGE}" &> /dev/null

	rm --force --recursive "${_TEST_APP_DIR}"

	unset _TEST_APP_DIR
	unset _TEST_DERIVED_IMAGE
	unset _TEST_NODE_RUNNER_IMAGE
}

function test_build_node_runner_image_derived_image_installs_dependencies {
	assert_equals \
		"$(docker run --entrypoint ls --rm "${_TEST_DERIVED_IMAGE}" node_modules)" \
		"left-pad"
}

function test_build_node_runner_image_entrypoint_passes_arguments {
	assert_equals \
		"$(_test_build_node_runner_image_run "${_TEST_NODE_RUNNER_IMAGE}" echo "[LIFERAY_NODE_RUNNER_TEST] argument" | \
			grep --fixed-strings "[LIFERAY_NODE_RUNNER_TEST] argument")" \
		"[LIFERAY_NODE_RUNNER_TEST] argument"
}

function test_build_node_runner_image_entrypoint_starts_default_command {
	assert_equals \
		"$(_test_build_node_runner_image_run "${_TEST_DERIVED_IMAGE}" | \
			grep --fixed-strings "[LIFERAY_NODE_RUNNER_TEST] started")" \
		"[LIFERAY_NODE_RUNNER_TEST] started"
}

function test_build_node_runner_image_has_node_on_path {
	assert_equals \
		"$(docker run --entrypoint bash --rm "${_TEST_NODE_RUNNER_IMAGE}" -c 'command -v node &> /dev/null && command -v npm &> /dev/null && echo "true"')" \
		"true"
}

function test_build_node_runner_image_switches_node_version {
	assert_equals \
		"$(_test_build_node_runner_image_node_version)" \
		"v22" \
		"$(NODE_VERSION="v24" _test_build_node_runner_image_node_version)" \
		"v24"
}

function _test_build_node_runner_image_node_version {
	_test_build_node_runner_image_run "${_TEST_NODE_RUNNER_IMAGE}" node --version | \
		grep --extended-regexp "^v[0-9]+" | \
		cut --delimiter='.' --fields=1
}

function _test_build_node_runner_image_run {
	local image="${1}"

	shift

	local environment_args=()

	if [ -n "${NODE_VERSION}" ]
	then
		environment_args+=("--env" "NODE_VERSION=${NODE_VERSION}")
	fi

	docker run \
		"${environment_args[@]}" \
		--rm \
		"${image}" \
		"${@}" 2>&1
}

main "${@}"