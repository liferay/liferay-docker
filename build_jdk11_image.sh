#!/bin/bash

source ./_build_jdk_image.sh
source ./_common.sh

function main {
	_build_docker_image "${1}" "JDK11" "base" "jdk11" "11"
}

main "${@}"