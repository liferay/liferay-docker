#!/bin/bash

if [ ! -f /etc/teleport/server.crt ];
then
	/usr/local/bin/generate-certificate.sh
fi

teleport start -c /etc/teleport/teleport.yaml