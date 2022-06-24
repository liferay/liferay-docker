#!/bin/bash

local db_password=$(cat ${MARIADB_ROOT_PASSWORD_FILE})

echo "local db_password=$(cat ${MARIADB_PASSWORD_FILE})" | mysql -u root -h127.0.0.1 -p${db_password}