#!/bin/bash

source ./_build_jdk_image.sh
source ./_common.sh

function main {
	_build_docker_image "${1}" "JDK21" "base" "jdk21" "21"
}

main "${@}"