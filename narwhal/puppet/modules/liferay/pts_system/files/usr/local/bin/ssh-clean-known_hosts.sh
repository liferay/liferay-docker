#!/bin/bash

if [ -z "${1}" ]
then
	echo "No hostname provided!"
	exit 1
fi

FORWARD_HOST="$1"
IP=$(host "${FORWARD_HOST}" | awk '{ print $4 }')
REVERSE_HOST=$(host "${IP}" | awk '{ print $5 }')

ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${FORWARD_HOST}"
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${IP}"
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "${REVERSE_HOST}"
