#!/bin/bash

docker_compose="docker compose"

if (command -v docker-compose &>/dev/null)
then
	docker_compose="docker-compose"
fi

for environment in $(ls | grep "env-")
do
	echo "Cleaning up ${environment}."

	cd "${environment}"
	${docker_compose} down

	docker image rm liferay:${environment}
	docker image rm search:${environment}

	cd ..

	rm -fr "${environment}"
done
