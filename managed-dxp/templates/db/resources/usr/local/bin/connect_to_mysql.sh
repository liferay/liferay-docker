#!/bin/bash

mysql -u root -p$(cat /run/secrets/sql_root_password) lportal