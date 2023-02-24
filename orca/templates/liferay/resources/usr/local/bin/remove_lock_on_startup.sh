#!/bin/bash

sleep 10

while (! cat /opt/liferay/tomcat/logs/* | grep "org.apache.catalina.startup.Catalina.start Server startup in" &>/dev/null)
do
	sleep 3
done

rm "/opt/liferay/data/liferay-startup-lock"