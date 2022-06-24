#!/bin/bash

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: orca <command>"
		echo ""
		echo "Available commands:"
		echo "  - bad: builds as 'latest' and deploys automatically"
		echo "  - build: calls build_services.sh"
		echo "  - down: calls docker-compose down"
		echo "  - install: installs this script"
		echo "  - up: validates the configuration and starts the services with docker-compose up"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_DB_BOOTSTRAP (optional): Set this to yes if you'd like to start a new database cluster."
		echo "    LIFERAY_DB_SKIP_WAIT (optional): Set this to false if you would like the db container to start without waiting for the others."

		exit 1
	fi
}

function command_bad {
	command_build latest

	command_deploy latest
}

function command_build {
	./build_services.sh ${@}
}

function command_deploy {
	cd builds

	if [ -e deploy ]
	then
		rm -rf deploy
	fi

	ln -s "${1}" deploy
}

function command_down {
	cd builds/deploy

	local service=${1}

	if [ -n "${service}" ]
	then
		service=$(get_service ${service})
	fi

	docker-compose down ${service}
}

function command_install {
	echo "#!/bin/bash" > /usr/local/bin/orca
	echo "" >> /usr/local/bin/orca
	echo "$(pwd)/orca.sh \${@}" >> /usr/local/bin/orca

	chmod a+x /usr/local/bin/orca
}

function command_up {
	if ( ! ./validate_environment.sh )
	then
		exit 1
	fi
	cd builds/deploy
	local service=${1}

	if [ -n "${service}" ]
	then
		service=$(get_service ${service})
	fi

	docker-compose up --remove-orphans ${service}
}

function get_service {
	docker-compose config --services | grep -m1 ${1}
}

function go_to_folder {
	local script_path=$(readlink /proc/$$/fd/255 2>/dev/null)

	cd $(dirname ${script_path})

}

function main {
	go_to_folder

	check_usage ${@}

	command_${1} "${2}" "${3}" "${4}"
}

main ${@}