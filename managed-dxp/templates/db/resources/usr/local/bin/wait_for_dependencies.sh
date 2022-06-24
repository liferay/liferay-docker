#!/bin/bash

function wait_for_primary {
	if [ -n "${LIFERAY_DB_SKIP_WAIT}" ]
	then
		echo "Skipping wait as LIFERAY_DB_SKIP_WAIT was set."

		return
	fi

	if [ -n "${MARIADB_GALERA_CLUSTER_BOOTSTRAP}" ]
	then
		echo "Bootstrap was requested, not blocking startup."

		return
	fi

	if [ ! -e /bitnami/mariadb/data/grastate.dat ]
	then
		echo "Couldn't find galera state file, not blocking startup."

		return
	fi

	if (grep "safe_to_bootstrap: 1" /bitnami/mariadb/data/grastate.dat &>/dev/null)
	then
		echo "This is the master node, not blocking startup."

		return
	fi

	local db_password=$(cat ${MARIADB_PASSWORD_FILE})

	while true
	do
		for db_address in ${LIFERAY_DB_ADDRESSES//,/ }
		do
			local db_host=${db_address%%:*}
			local db_password

			if (echo "select 1" | mysql --connect-timeout=3 -h${db_host} -p${db_password} -u${MARIADB_USER} &>/dev/null)
			then
				echo "Successfully opened connection to ${db_host}."

				return
			fi
		done

		echo "Unsuccessful connections to ${LIFERAY_DB_ADDRESSES}. Waiting."

		sleep 3
	done
}

function main {
	wait_for_primary
}

main