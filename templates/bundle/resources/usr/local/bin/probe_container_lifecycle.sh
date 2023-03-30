#!/bin/bash

if [[ "${LIFERAY_CONTAINER_STATUS_ENABLED}" != "true" ]]
then
	echo "Set LIFERAY_CONTAINER_STATUS_ENABLED to true to enable this probe."

	exit 2
fi

if [ ! -e /opt/liferay/container_status ]
then
	echo "/opt/liferay/container_status does not exist, fail."

	exit 4
fi

if [ "$(find /opt/liferay/container_status -mmin +2)" ]
then
	echo "The /opt/liferay/container_status file was not updated for more than two minutes, the container status script is not running properly."

	exit 5
fi

cat /opt/liferay/container_status

if (cat /opt/liferay/container_status | grep -q "status=live")
then
	exit 0
else
	exit 1
fi
