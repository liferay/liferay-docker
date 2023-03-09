#!/bin/bash

LANG=C
OS=$(uname -s)

if [ "$OS" == "Linux" ]
then
	DEFAULT_IF=$(netstat -rn | awk '$1=="0.0.0.0" { print $8 }')
else
	echo "Unsupported OS"
	exit 255
fi

echo "$DEFAULT_IF"
