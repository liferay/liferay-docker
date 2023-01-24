#!/bin/bash

function main {
	if [ -n "${MARIADB_GALERA_CLUSTER_BOOTSTRAP}" ]
	then
		echo "Do not wait for dependencies because the environment variable MARIADB_GALERA_CLUSTER_BOOTSTRAP was set."

		return
	fi

	if [ -n "${ORCA_DB_SKIP_WAIT}" ]
	then
		echo "Do not wait for dependencies because the environment variable ORCA_DB_SKIP_WAIT was set."

		return
	fi

	if [ ! -e "/bitnami/mariadb/data/grastate.dat" ]
	then
		echo "Do not wait for dependencies because Galera state file does not exist."

		return
	fi

	if (grep "safe_to_bootstrap: 1" "/bitnami/mariadb/data/grastate.dat" &>/dev/null)
	then
		echo "Do not wait for dependencies because this is the master node."

		return
	fi

	local db_password=$(cat ${MARIADB_PASSWORD_FILE})

	while true
	do
		for db_address in ${ORCA_DB_ADDRESSES//,/ }
		do
			local db_host="${db_address%%:*}"

			if (echo "select 1" | mysql --connect-timeout=3 -h${db_host} -p${db_password} -u${MARIADB_USER} &>/dev/null)
			then
				echo "Connected to ${db_host}."

				return
			fi
		done

		echo "Unable to connect to ${ORCA_DB_ADDRESSES}. Waiting."

		sleep 3
	done
}

main
