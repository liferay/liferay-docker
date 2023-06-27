#!/bin/bash

source /usr/local/bin/_liferay_common.sh

function check_usage {
	lc_check_utils mysql

	LIFERAY_REPORTS_DIRECTORY="${LIFERAY_HOME}/data/reports"

	mkdir -p "${LIFERAY_REPORTS_DIRECTORY}"
}

function generate_reports {
	echo "Generating database status and query reports to ${LIFERAY_REPORTS_DIRECTORY}"

	(
		run_query "${LCP_SECRET_DATABASE_NAME}" "SHOW ENGINE INNODB STATUS;"

		run_query INFORMATION_SCHEMA "SELECT * FROM INNODB_LOCK_WAITS;"

		run_query INFORMATION_SCHEMA "SELECT * FROM INNODB_LOCKS WHERE LOCK_TRX_ID IN (SELECT BLOCKING_TRX_ID FROM INNODB_LOCK_WAITS);"

		run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM VirtualHost;"

		run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT TABLE_NAME, TABLE_ROWS from information_schema.TABLES;"

		run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM DDMTemplate;"

		run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM FragmentEntryLink;"

		run_query "${LCP_SECRET_DATABASE_NAME}" "SELECT * FROM QUARTZ_TRIGGERS;"

	) > ${LIFERAY_REPORTS_DIRECTORY}/query_report_$(date +'%Y-%m-%d_%H-%M-%S').html

	echo "Generated database status and query reports to ${LIFERAY_REPORTS_DIRECTORY}"
}

function main {
	check_usage

	generate_reports
}

function run_query {
	echo "<h1>${2}</h1>"

	mysql --connect-timeout=10 -D "${1}" -e "${2}" -H -u "${LCP_SECRET_DATABASE_USER}" -p"${LCP_SECRET_DATABASE_PASSWORD}"
}

main "${@}"