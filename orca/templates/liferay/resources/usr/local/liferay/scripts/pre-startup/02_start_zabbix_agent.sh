#!/bin/bash

if [ "${ORCA_LIFERAY_ZABBIX_AGENT_ENABLED}" == "true" ]
then
	echo "Starting zabbix agent."

	/usr/sbin/zabbix_agent2 -c /etc/zabbix/zabbix_agent2.conf &
else
	echo "Set the environment variable ORCA_LIFERAY_ZABBIX_AGENT_ENABLED to true to start the Zabbix agent."
fi