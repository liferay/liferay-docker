#!/bin/bash

openssl req -subj '/CN=192.168.233.141/O=Liferay/C=HU' -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -keyout /etc/teleport/server.key -out /etc/teleport/server.crt
