#!/bin/bash

fetch_orca_secrets.sh db mysql_backup_password mysql_liferay_password mysql_root_password

wait_for_dependencies.sh

/usr/local/bin/percona_entrypoint.sh ${@}