#!/bin/bash

mkdir /opt/liferay/liferay/data
chmod 0775 /opt/liferay/liferay/data
chown 1000:1000 /opt/liferay/liferay/data

sysctl -w vm.max_map_count=262144
