#!/bin/bash

source ./_liferay_common.sh
source ./_test_common.sh

function main {
	set_up

	if [[ "${#}" -eq 1 ]]
	then
		"${1}"
	else
		test_build_caddy_image_allows_dxp_origins
		test_build_caddy_image_redirects_not_found
		test_build_caddy_image_regenerates_caddy_file_on_restart
		test_build_caddy_image_serves_static_files
	fi

	tear_down
}

function set_up {
	export _TEST_APP_DIR=$(mktemp --directory)

	export _TEST_CADDY_IMAGE="liferay/caddy:test"

	docker build --tag "${_TEST_CADDY_IMAGE}" templates/caddy &> /dev/null

	mkdir --parents "${_TEST_APP_DIR}/dxp-metadata" "${_TEST_APP_DIR}/static"

	echo "able.example.com baker.example.com" > "${_TEST_APP_DIR}/dxp-metadata/com.liferay.lxc.dxp.domains"
	echo "https" > "${_TEST_APP_DIR}/dxp-metadata/com.liferay.lxc.dxp.server.protocol"

	echo "[LIFERAY_CADDY_TEST] static" > "${_TEST_APP_DIR}/static/test.txt"

	cat <<- EOF > "${_TEST_APP_DIR}/Dockerfile"
	FROM ${_TEST_CADDY_IMAGE}

	COPY static/ /public_html/
	EOF

	export _TEST_DERIVED_IMAGE="liferay/caddy-derived:test"

	docker build --tag "${_TEST_DERIVED_IMAGE}" "${_TEST_APP_DIR}" &> /dev/null
}

function tear_down {
	docker rmi --force "${_TEST_DERIVED_IMAGE}" &> /dev/null
	docker rmi --force "${_TEST_CADDY_IMAGE}" &> /dev/null

	rm --force --recursive "${_TEST_APP_DIR}"

	unset _TEST_APP_DIR
	unset _TEST_CADDY_IMAGE
	unset _TEST_DERIVED_IMAGE
}

function test_build_caddy_image_allows_dxp_origins {
	local container_id=$(_test_build_caddy_image_start_container)

	assert_equals \
		"$(_test_build_caddy_image_response_header "${container_id}" "Access-Control-Allow-Origin" "https://baker.example.com")" \
		"Access-Control-Allow-Origin: https://baker.example.com"

	docker rm --force "${container_id}" &> /dev/null
}

function test_build_caddy_image_redirects_not_found {
	local container_id=$(_test_build_caddy_image_start_container --env LIFERAY_CADDY_404_URL=https://www.example.com/404)

	assert_equals \
		"$(_test_build_caddy_image_response_header "${container_id}" "Location" "" "/missing.txt")" \
		"Location: https://www.example.com/404"

	docker rm --force "${container_id}" &> /dev/null
}

function test_build_caddy_image_regenerates_caddy_file_on_restart {
	local container_id=$(_test_build_caddy_image_start_container)

	docker restart "${container_id}" &> /dev/null

	_test_build_caddy_image_wait_for_caddy "${container_id}"

	assert_equals \
		"$(docker exec "${container_id}" cat /etc/caddy.d/liferay_caddy_file)" \
		"$( \
			cat <<- EOF
			@originhttps://able.example.com header Origin https://able.example.com
			header @originhttps://able.example.com Access-Control-Allow-Origin "https://able.example.com"
			@originhttps://baker.example.com header Origin https://baker.example.com
			header @originhttps://baker.example.com Access-Control-Allow-Origin "https://baker.example.com"
			EOF
		)" \
		"$(docker inspect --format "{{.State.Running}}" "${container_id}")" \
		"true"

	docker rm --force "${container_id}" &> /dev/null
}

function test_build_caddy_image_serves_static_files {
	local container_id=$(_test_build_caddy_image_start_container)

	assert_equals \
		"$( \
			docker exec \
				"${container_id}" \
				wget \
					--output-document - \
					--quiet \
					http://localhost/test.txt)" \
		"[LIFERAY_CADDY_TEST] static"

	docker rm --force "${container_id}" &> /dev/null
}

function _test_build_caddy_image_response_header {
	local origin_header=()

	if [ -n "${3}" ]
	then
		origin_header=(--header "Origin: ${3}")
	fi

	docker exec \
		"${1}" \
		wget \
			"${origin_header[@]}" \
			--output-document /dev/null \
			--quiet \
			--server-response \
			"http://localhost${4:-/test.txt}" 2>&1 | \
		grep --fixed-strings "${2}:" | \
		head --lines=1 | \
		sed --expression "s/^ *//" --expression "s/\r$//"
}

function _test_build_caddy_image_start_container {
	local container_id=$( \
		docker run \
			--detach \
			--volume "${_TEST_APP_DIR}/dxp-metadata:/etc/liferay/lxc/dxp-metadata:ro" \
			"${@}" \
			"${_TEST_DERIVED_IMAGE}")

	_test_build_caddy_image_wait_for_caddy "${container_id}"

	echo "${container_id}"
}

function _test_build_caddy_image_wait_for_caddy {
	local counter

	for counter in {1..30}
	do
		if docker exec \
				"${1}" \
				wget \
					--output-document /dev/null \
					--quiet \
					http://localhost/ &> /dev/null
		then
			break
		fi

		sleep 1
	done
}

main "${@}"