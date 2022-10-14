#!/bin/bash

function main {
	if [ "${LIFERAY_ZABBIX_AGENT_ENABLED}" == "true" ]
	then
		echo ""
		echo "[LIFERAY] Starting Zabbix Agent2."
		echo ""

		/usr/sbin/zabbix_agent2 -c /etc/zabbix/zabbix_agent2.conf &
	fi
}

main