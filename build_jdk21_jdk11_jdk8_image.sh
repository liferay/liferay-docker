#!/bin/bash

source ./_common.sh

source ./_build_jdk_image.sh

function main {
	_build_docker_image "${1}" "JDK21 JDK11 JDK8" "jdk11-jdk8" "jdk21-jdk11-jdk8" "21"
}

main "${@}"