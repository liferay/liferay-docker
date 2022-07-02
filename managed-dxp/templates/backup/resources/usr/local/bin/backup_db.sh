#/bin/bash

set -e
set -o pipefail

function backup {
	echo "Starting database backup."

	local database_server_address
	for database_server_address in ${LIFERAY_DB_ADDRESSES//,/ }
	do
		echo "Trying to dump the database from ${database_server_address}."

		local db_host="${database_server_address%%:*}"

		if (mysqldump -h "${db_host}" -u "root" -p"$(cat /run/secrets/sql_root_password)" "lportal" | gzip > "${BACKUP_DIR}/db-lportal-${TIMESTAMP}.sql.gz")
		then
			local backup_success=1

			break
		fi
	done

	if [ -n "${backup_success}" ]
	then
		echo "Database backup was completed successfully."
	else
		echo "Database backup failed, please check the logs."
	fi
}

function check_usage {
	BACKUP_DIR="${1}"
	TIMESTAMP="${2}"

	if [ ! -n ${LIFERAY_DB_ADDRESSES} ]
	then
		echo "Set the LIFERAY_DB_ADDRESSES environment variable to comma separated list of database servers. Example: db-1:3306,db2:3306"

		exit 1
	fi
}

function main {
	check_usage ${@}

	backup
}

main ${@}