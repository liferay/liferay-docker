#!/bin/bash

set -e

# shellcheck disable=SC1091
. _liferay_common.sh

fetch_orca_secrets.sh db mysql_backup_password mysql_liferay_password mysql_root_password

mysql_init.sh

block_begin "Start mysqld process"
mysqld