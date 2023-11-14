#!/bin/bash

if [ -z "${1}" ]
then
	echo "Missing argument."

	exit 1
fi

docker compose -f docker-compose.yaml ${@}
