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
			db_host=${db_host%%:*}

			local db_user=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME}
			local db_password=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD}

			if [ -n "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE}" ]
			then
				db_password=$(cat ${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE})
			fi

			echo "Testing database server connection to ${db_user}@${db_host}."

			while ! (echo "select 1" | mysql -h ${db_host} -p${db_password} -u ${db_user} &>/dev/null)
			do
				echo "Waiting for database server to become online: ${db_user}@${db_host}."

				sleep 3
			done

			echo "Database server ${db_user}@${db_host} is available."
		fi
	fi
}

function wait_for_search {
	if [ ! -n {LIFERAY_SEARCH_ADDRESSES} ]
	then
		echo "There's no remote search service configured."

		return
	fi

	echo "Testing search service connections: ${LIFERAY_SEARCH_ADDRESSES}."

	while true
	do
		for search_address in ${LIFERAY_SEARCH_ADDRESSES//,/ }
		do
			if ( curl --max-time 3 --silent "${search_address}/_cat/health" | grep green &>/dev/null)
			then
				echo "Search service ${search_address} is reporting green."

				return
			fi
		done

		echo "Waiting for at least one search server to report green status (${LIFERAY_SEARCH_ADDRESSES})."

		sleep 3
	done
}

function main {
	wait_for_mysql

	wait_for_search
}

main