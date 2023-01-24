#!/bin/bash

mysql -p$(cat /run/secrets/mysql_root_password) -u root lportal
