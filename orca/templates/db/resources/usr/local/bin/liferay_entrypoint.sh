#!/bin/bash

fetch_orca_secrets.sh mysql_backup_password mysql_liferay_password mysql_root_password

wait_for_dependencies.sh

/opt/bitnami/scripts/mariadb-galera/entrypoint.sh ${@}