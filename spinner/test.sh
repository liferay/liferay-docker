#!/bin/bash

source ../_liferay_common.sh

set -o pipefail

function build {
	./build.sh
}

function clean {
	./clean.sh

	rm -fr "${LIFERAY_COMMON_LOG_DIR}"
}

function main {
	LIFERAY_COMMON_LOG_DIR=test_log

	lc_time_run clean

	lc_time_run build

	lc_cd env-*

	lc_time_run up

	lc_time_run wait_for_startup

	lc_cd ..

	lc_time_run clean
}

function up {
	$(lc_docker_compose) up -d antivirus database liferay-1 search web-server
}

function wait_for_startup {
	for count in {1..1000}
	do
		if (curl --fail --max-time 3 http://localhost | grep -q "Liferay Digital Experience Platform")
		then
			return 0
		fi

		sleep 1
	done

	return 1
}

main "${@}"