#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function check_usage {
	lc_check_utils mysql || exit 1

	LIFERAY_REPORTS_DIRECTORY="${LIFERAY_HOME}/data/reports"

	mkdir -p "${LIFERAY_REPORTS_DIRECTORY}"

	REPORTS_FILE="${LIFERAY_REPORTS_DIRECTORY}"/query_report_$(date +'%Y-%m-%d_%H-%M-%S').html
}

function main {
	check_usage

	lc_time_run run_query "${LCP_SECRET_DATABASE_NAME}" "SHOW ENGINE INNODB STATUS;"

	lc_time_run run_query INFORMATION_SCHEMA "SELECT * FROM INNODB_LOCK_WAITS;"

	lc_time_run run_query INFORMATION_SCHEMA "SELECT * FROM INNODB_LOCKS WHERE LOCK_TRX_ID IN (SELECT BLOCKING_TRX_ID FROM INNODB_LOCK_WAITS);"

	lc_time_run run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM VirtualHost;"

	lc_time_run run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT TABLE_NAME, TABLE_ROWS from information_schema.TABLES;"

	lc_time_run run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM DDMTemplate;"

	lc_time_run run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM FragmentEntryLink;"

	lc_time_run run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM QUARTZ_TRIGGERS;"
}

function run_query {
	echo "<h1>${2}</h1>" >> "${REPORTS_FILE}"

	mysql --connect-timeout=10 -D "${1}" -e "${2}" -H -u "${LCP_SECRET_DATABASE_USER}" -p"${LCP_SECRET_DATABASE_PASSWORD}" >> "${REPORTS_FILE}"
}

main "${@}"