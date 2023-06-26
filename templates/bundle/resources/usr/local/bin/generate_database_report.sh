#!/bin/bash

function generate_reports {
	
	mkdir -p "${LIFERAY_HOME}/data/reports"
	LIFERAY_REPORTS_DIRECTORY="${LIFERAY_HOME}/data/reports"

	if (! mysql -V | grep mysql &>/dev/null)
	then
		echo "MySQL client is not available to generate reports using ./generate_report.sh."
	else
		echo "Generating database status and query reports to ${LIFERAY_REPORTS_DIRECTORY}"

		mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -u ${LCP_SECRET_DATABASE_USER} -p${LCP_SECRET_DATABASE_PASSWORD} -E -e "SHOW ENGINE INNODB STATUS;" > ${LIFERAY_REPORTS_DIRECTORY}/database_status_$(date +'%Y-%m-%d_%H-%M-%S').txt

		(
			echo "<h1>INNODB_LOCK_WAITS</h1>" > outputfile
			mysql -D INFORMATION_SCHEMA --connect-timeout=10 -u ${LCP_SECRET_DATABASE_USER} -p${LCP_SECRET_DATABASE_PASSWORD} -H -e "SELECT * FROM INNODB_LOCK_WAITS;"

			mysql -D INFORMATION_SCHEMA --connect-timeout=10 -u ${LCP_SECRET_DATABASE_USER} -p${LCP_SECRET_DATABASE_PASSWORD} -H -e "SELECT * FROM INNODB_LOCKS WHERE LOCK_TRX_ID IN (SELECT BLOCKING_TRX_ID FROM INNODB_LOCK_WAITS);"

			echo "<h1>AVAILABLE VIRTUAL INSTANCES</h1>"
			mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM VirtualHost;"

			echo "<h1>COUNT OF RECORDS ON EACH TABLE</h1>"
			mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT TABLE_NAME, TABLE_ROWS from information_schema.TABLES;"

			echo "<h1>DDMTEMPLATE CONTENTS</h1>"
			mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM DDMTemplate;"

			echo "<h1>FRAGMENT SOURCES(HTML, CSS ..)</h1>"
			mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM FragmentEntryLink;"

			echo "<h1>QUARTZ TRIGGERS</h1>"
			mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM QUARTZ_TRIGGERS;"

		) > ${LIFERAY_REPORTS_DIRECTORY}/query_report_$(date +'%Y-%m-%d_%H-%M-%S').html

		echo "Generated database status and query reports to ${LIFERAY_REPORTS_DIRECTORY}"
	fi
}

generate_reports