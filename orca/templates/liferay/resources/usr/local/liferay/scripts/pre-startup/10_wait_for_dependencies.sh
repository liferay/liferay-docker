#!/bin/bash

function wait_for_mysql {
	local jdbc_driver_class_name="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME}"

	if [[ "${jdbc_driver_class_name}" != *mariadb* ]] && [[ "${jdbc_driver_class_name}" != *mysql* ]]
	then
		return
	fi

	local db_host="${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL}"

	db_host="${db_host##*://}"
	db_host="${db_host%%/*}"
	db_host="${db_host%%:*}"

	local db_password=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD}

	if [ -n "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE}" ]
	then
		db_password=$(cat "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE}")
	fi

	local db_username=${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME}

	echo "Connecting to database server ${db_username}@${db_host}."

	while ! (echo "select 1" | mysql -h "${db_host}" -p"${db_password}" -u "${db_username}" &>/dev/null)
	do
		echo "Waiting for database server ${db_username}@${db_host}."

		sleep 3
	done

	echo "Database server ${db_username}@${db_host} is available."
}

function wait_for_search {
	if [ ! -n "${ORCA_LIFERAY_SEARCH_ADDRESSES}" ]
	then
		echo "Do not wait for search server because the environment variable ORCA_LIFERAY_SEARCH_ADDRESSES was not set."

		return
	fi

	echo "Connecting to ${ORCA_LIFERAY_SEARCH_ADDRESSES}."

	while true
	do
		for search_address in ${ORCA_LIFERAY_SEARCH_ADDRESSES//,/ }
		do
			if ( curl --max-time 3 --silent "${search_address}/_cat/health" | grep "green" &>/dev/null)
			then
				echo "Search server ${search_address} is available."

				return
			fi
		done

		echo "Waiting for at least one search server to become available."

		sleep 3
	done
}

function main {
	wait_for_mysql

	wait_for_search
}

main