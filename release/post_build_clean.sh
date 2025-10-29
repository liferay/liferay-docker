#!/bin/bash

source ./_liferay_common.sh

function main {
	lc_log INFO "Cleaning build."

	docker system prune --all --force &> /dev/null

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