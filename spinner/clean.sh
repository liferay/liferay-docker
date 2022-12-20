#!/bin/bash

echo "Starting cleanup process"

for available_environment in $(ls | grep "env-")
do
	cd "${available_environment}" || exit
	echo "Deleting ${available_environment} docker compose environment"
	docker-compose -p "${available_environment}" rm -s -f -v

	echo "Deleting ${available_environment} docker volume"
	docker volume rm -f "${available_environment}_mysql-db"

	echo "Deleting ${available_environment} docker network"
	docker network rm "${available_environment}_default"

	cd ..

	echo "Deleting ${available_environment} directory"
	rm -fr "${available_environment}"
done

echo "Finished cleanup process"
