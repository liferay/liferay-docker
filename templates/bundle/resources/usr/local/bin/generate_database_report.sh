#!/bin/bash

function generate_reports {
	
	mkdir -p "${LIFERAY_HOME}/data/reports"
	LIFERAY_REPORTS_DIRECTORY="${LIFERAY_HOME}/data/reports"

	if (! mysql -V | grep mysql &>/dev/null)
	then
    	echo "MySQL client is not available to generate reports using ./generate_report.sh."
	else
    	echo "Generating database status and query reports to ${LIFERAY_REPORTS_DIRECTORY}"

    	mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -u ${LCP_SECRET_DATABASE_USER} -p${LCP_SECRET_DATABASE_PASSWORD} -E -e "SHOW ENGINE INNODB STATUS;" > database_status

    	mv database_status ${LIFERAY_REPORTS_DIRECTORY}/database_status_$(date +'%Y-%m-%d_%H-%M-%S').text

    	echo "<br> <br> <b>INNODB_LOCK_WAITS<b> <br> <br>" > outputfile
    	mysql -D INFORMATION_SCHEMA --connect-timeout=10 -u ${LCP_SECRET_DATABASE_USER} -p${LCP_SECRET_DATABASE_PASSWORD} -H -e "SELECT * FROM INNODB_LOCK_WAITS;" >> outputfile

    	mysql -D INFORMATION_SCHEMA --connect-timeout=10 -u ${LCP_SECRET_DATABASE_USER} -p${LCP_SECRET_DATABASE_PASSWORD} -H -e "SELECT * FROM INNODB_LOCKS WHERE LOCK_TRX_ID IN (SELECT BLOCKING_TRX_ID FROM INNODB_LOCK_WAITS);" >> outputfile

    	echo "<br> <br> <b>AVAILABLE VIRTUAL INSTANCES<b> <br> <br>" >> outputfile
    	mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM VirtualHost;" >> outputfile

    	echo "<br> <br> <b>COUNT OF RECORDS ON EACH TABLE<b> <br> <br>" >> outputfile
    	mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT TABLE_NAME, TABLE_ROWS from information_schema.TABLES;" >> outputfile

    	echo "<br> <br> <b>DDMTEMPLATE CONTENTS<b> <br> <br>" >> outputfile
    	mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM DDMTemplate;" >> outputfile

    	echo "<br> <br> <b>FRAGMENT SOURCES(HTML, CSS ..)<b> <br> <br>" >> outputfile
    	mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM FragmentEntryLink;" >> outputfile

    	echo "<br> <br> <b>QUARTZ TRIGGERS<b> <br> <br>" >> outputfile
    	mysql -D "$LCP_SECRET_DATABASE_NAME" --connect-timeout=10 -H -e "SELECT * FROM QUARTZ_TRIGGERS;" >> outputfile

    	mv outputfile ${LIFERAY_REPORTS_DIRECTORY}/query_report_$(date +'%Y-%m-%d_%H-%M-%S').html

    	echo "Generated database status and query reports to ${LIFERAY_REPORTS_DIRECTORY}"
	fi
}

generate_reports