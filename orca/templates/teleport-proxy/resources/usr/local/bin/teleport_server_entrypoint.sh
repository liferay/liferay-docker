#!/bin/bash

if [ ! -f /etc/teleport/server.crt ]
then
	openssl req -days 3650 -keyout /etc/teleport/server.key -new -newkey rsa:2048 -nodes -out /etc/teleport/server.crt -sha256 -subj "/CN=192.168.233.141/O=Liferay/C=HU" -x509
fi

teleport start -c /etc/teleport/teleport.yaml