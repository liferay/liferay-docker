#!/bin/bash

wait_for_dependencies.sh

/opt/bitnami/scripts/mariadb-galera/entrypoint.sh ${@}