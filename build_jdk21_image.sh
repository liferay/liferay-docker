#!/bin/bash

source ./_common.sh

source ./_build_jdk_image.sh

function main {
	_build_docker_image "${1}" "JDK21" "jdk21" "21"
}

main "${@}"