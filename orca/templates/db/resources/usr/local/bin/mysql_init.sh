#!/bin/bash

set -e

# Inspired by Percona's MySQL docker image, might share code snippets

# shellcheck disable=SC1091
. _liferay_common.sh

function check_setup {
	block_begin "Check if MySQL set up."

	if [ -d /var/lib/mysql/data/mysql ]
	then
		block_finish "Check if MySQL is set up: DONE"

		exit 0
	else
		block_finish "Check if MySQL is set up: NOT DONE"
	fi
}

function init_datadir {
	block_begin "Datadir initialization."

	install -v -o mysql -g mysql -m 0700 -d "${HOME}/data" "${HOME}/log"

	mysqld --initialize-insecure

	block_finish "Datadir initialization."
}

function init_liferay_db {
	block_begin "Initialize 'lportal' database"

	mysql <<-EOSQL
		CREATE DATABASE lportal;
		CREATE USER 'lportal'@'%' IDENTIFIED BY '${MYSQL_LIFERAY_PASSWORD}';
		GRANT ALL ON lportal.* TO 'lportal'@'%';
		FLUSH PRIVILEGES ;
	EOSQL

	block_finish "Initialize 'lportal' database."
}

function get_vault_mysql_liferay_password {
	MYSQL_LIFERAY_PASSWORD=$(cat /tmp/orca-secrets/mysql_liferay_password)

	if [ -z "${MYSQL_LIFERAY_PASSWORD}" ]
	then
		fail "MYSQL_LIFERAY_PASSWORD is not set"

		exit 1
	fi
}

function get_vault_mysql_root_password {
	MYSQL_ROOT_PASSWORD=$(cat /tmp/orca-secrets/mysql_root_password)

	if [ -z "${MYSQL_ROOT_PASSWORD}" ]
	then
		fail "MYSQL_ROOT_PASSWORD is not set"

		exit 1
	fi

	echo -e "[client]\nuser = root" > "${HOME}/.my.cnf"
}

function load_timezones {
	block_begin "Load time zones."

	mysql_tzinfo_to_sql /usr/share/zoneinfo | sed "s/Local time zone must be set--see zic manual page/FCTY/" | mysql mysql

	block_finish "Load time zones."
}

function main {
	check_setup

	get_vault_mysql_liferay_password

	get_vault_mysql_root_password

	init_datadir

	start_temporary

	load_timezones

	set_basics

	init_liferay_db

	shut_down_temporary
}

function set_basics {
	block_begin "Set the basics of the 'mysql' database."

	mysql <<-EOSQL
		-- What's done in this file shouldn't be replicated or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0 ;

		CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so' ;
		CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so' ;
		CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so' ;

		DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'mysql.infoschema', 'mysql.session', 'root') OR host NOT IN ('localhost') ;
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
		FLUSH PRIVILEGES ;
	EOSQL

	echo -e "[client]\nuser = root\npassword = ${MYSQL_ROOT_PASSWORD}" > "${HOME}/.my.cnf"

	block_finish "Set the basics of the 'mysql' database."
}

function start_temporary {
	block_begin "Initialize the 'mysql' database, temporary first run."

	mysqld --skip-networking &
	pid="$!"

	for second in {120..0}
	do
		msg "MySQL init process in progress... ${second} seconds left."

		if (echo 'SELECT 1' | mysql &>/dev/null)
		then
			break
		fi

		sleep 1
	done

	if [ "${second}" = 0 ]
	then
		fail "MySQL init process failed"

		exit 1
	fi

	block_finish "Initialize the 'mysql' database, temporary first run"
}

function shut_down_temporary {
	block_begin "Shutting down the temporary mysqld instance"

	msg "kill -s TERM ${pid}"

	if (! kill -s TERM "${pid}" || wait "${pid}")
	then
		fail "Temporary mysql instance cannot be shut down"

		exit 1
	fi

	block_finish "Shutting down the temporary mysqld instance"
}

main