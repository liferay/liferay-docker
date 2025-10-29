#!/bin/bash

source ./_liferay_common.sh

function main {
	lc_log INFO "Cleaning build."

	docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | \
		grep --extended-regexp ":.*(-slim).*" | \
		awk '{print $2}' | \
		xargs --no-run-if-empty docker rmi --force &> /dev/null

	docker rmi $(docker images --filter "dangling=true" --no-trunc) &> /dev/null
	docker rmi --force "liferay/jdk11-jdk8:latest" &> /dev/null
	docker rmi --force "liferay/jdk11:latest" &> /dev/null
	docker rmi --force "liferay/jdk21-jdk11-jdk8:latest" &> /dev/null
	docker rmi --force "liferay/jdk21:latest" &> /dev/null

	for file in $(find $(find . -name "logs-20*" -type d) -name "build*image_id.txt" -type f)
	do
		docker rmi --force $(cat "${file}" | cut --delimiter=':' --fields=2) &> /dev/null
	done

	for dir in "logs-20*" "temp-*"
	do
		find . /opt/dev/projects/github/liferay-docker \
			-maxdepth 1 \
			-mtime +6 \
			-name "${dir}" \
			-type d \
			-exec rm --force --recursive {} \; &> /dev/null
	done
}

main