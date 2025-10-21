#!/bin/bash

function main {
	export LIFERAY_COMMON_DOWNLOAD_SKIP_CACHE="true"
	export LIFERAY_RELEASE_GIT_REF="master"
	export LIFERAY_RELEASE_OUTPUT="nightly"
	export LIFERAY_RELEASE_UPLOAD="true"

	./build_release.sh
}

main