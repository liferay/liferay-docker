#!/bin/bash

db_password=$(cat "${MARIADB_ROOT_PASSWORD_FILE}")

echo "SET GLOBAL wsrep_provider_options='pc.bootstrap=YES'" | mysql -h127.0.0.1 "-p${db_password}" -u root