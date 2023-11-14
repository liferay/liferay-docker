#!/bin/bash

mkdir -p /opt/liferay/db/data
chmod 0775 /opt/liferay/db/data
chown 999:999 /opt/liferay/db/data

sysctl -w vm.max_map_count=262144
