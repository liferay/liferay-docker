#!/bin/bash

function wait_for_mysql {
	local driver=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME}
	if [ -n "${driver}" ]
	then
		if (echo $driver | grep -i mysql &>/dev/null) || (echo $driver | grep -i mariadb &>/dev/null)
		then
			local db_host=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL}
			db_host=${db_host##*://}
			db_host=${db_host%%/*}

			local db_user=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME}
			local db_password=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD}

			while ! (echo "select 1" | mysql -h ${db_host} -p${db_password} -u ${db_user} &>/dev/null)
			do
				echo "Waiting for database server to become online: ${db_user}@${db_host}."

				sleep 3
			done
		fi
	fi
}

function main {
	wait_for_mysql
}

main