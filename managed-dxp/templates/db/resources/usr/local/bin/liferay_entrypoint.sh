#!/bin/bash

echo Tomcat
echo "$1"
wait_for_dependencies.sh

/opt/bitnami/scripts/mariadb-galera/entrypoint.sh ${@}