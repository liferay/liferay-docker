#!/bin/bash

if [[ "${LIFERAY_CONTAINER_STATUS_ENABLED}" != "true" ]]
then
	echo "Set the environment variable \"LIFERAY_CONTAINER_STATUS_ENABLED\" to \"true\" to enable ${0}."

	exit 2
fi

if [ ! -e /opt/liferay/container_status ]
then
	echo "The file /opt/liferay/container_status does not exist."

	exit 4
fi

if [ "$(find /opt/liferay/container_status -mmin +2)" ]
then
	echo "The file /opt/liferay/container_status file has not been updated for more than two minutes."

	exit 5
fi

cat /opt/liferay/container_status

if (cat /opt/liferay/container_status | grep -q "status=live")
then
	exit 0
else
	exit 1
fi