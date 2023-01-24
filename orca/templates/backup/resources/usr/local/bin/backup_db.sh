#/bin/bash

set -e
set -o pipefail

function check_usage {
	if [ ! -n ${ORCA_DB_ADDRESSES} ]
	then
		echo "Set the environment variable ORCA_DB_ADDRESSES to a comma separated list of database servers (e.g. db-1:3306,db-2:3306)."

		exit 1
	fi
}

function main {
	check_usage

	echo "Starting database backup."

	local db_address

	for db_address in ${ORCA_DB_ADDRESSES//,/ }
	do
		echo "Dumping ${db_address}."

		local db_host=${db_address%%:*}

		if (mysqldump -h ${db_host} -p$(cat /tmp/orca-secrets/mysql_root_password) -u root lportal | gzip > ${1}/db-lportal-${2}.sql.gz)
		then
			local success=1

			break
		fi
	done

	if [ -n "${success}" ]
	then
		echo "Database backup was completed successfully."
	else
		echo "Database backup failed, please check the logs."
	fi
}

main "${@}"
