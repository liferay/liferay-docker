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
		echo "  - force_primary: changes the database configuration and makes the current server the primary. Only use this in emergencies and on the node which was last written by the cluster."
		echo "  - install: installs this script"
		echo "  - mysql: logs into the db server on this container"
		echo "  - ssh <service name>: logs in to the named service container"
		echo "  - up: validates the configuration and starts the services with docker-compose up"
		echo ""
		echo "All other commands are executed as docker-compose commands from the correct folder."
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_DB_BOOTSTRAP (optional): Set this to yes if you'd like to start a new database cluster."
		echo "    LIFERAY_DB_SKIP_WAIT (optional): Set this to false if you would like the db container to start without waiting for the others."
		echo ""
		echo "Examples:"
		echo "  - orca up -d liferay: starts the Liferay service in the background"
		echo "  - orca ps: shows the list of running services"

		exit 1
	fi
}

function command_bad {
	command_build "latest"

	command_deploy "latest"
}

function command_build {
	./build_services.sh ${@}
}

function command_deploy {
	cd "builds"

	if [ -e "deploy" ]
	then
		rm -rf "deploy"
	fi

	ln -s "${1}" "deploy"
}

function command_down {
	cd "builds/deploy"

	local service="${1}"

	if [ -n "${service}" ]
	then
		service=$(get_service ${service})
	fi

	docker-compose down ${service}
}

function command_force_primary {
	sed -i "s/safe_to_bootstrap: 0/safe_to_bootstrap: 1/" /opt/liferay/db-data/data/grastate.dat
}

function command_install {
	echo "#!/bin/bash" > "/usr/local/bin/orca"
	echo "" >> "/usr/local/bin/orca"
	echo "$(pwd)/orca.sh \${@}" >> "/usr/local/bin/orca"

	chmod a+x "/usr/local/bin/orca"
}

function command_mysql {
	cd "builds/deploy"

	docker-compose exec "$(get_service db)" "/usr/local/bin/connect_to_mysql.sh"
}

function command_ssh {
	service="${1}"

	cd "builds/deploy"

	docker-compose exec "$(get_service ${service})" "/bin/bash"
}

function command_up {
	if ( ! ./validate_environment.sh )
	then
		exit 1
	fi

	cd "builds/deploy"

	local other_params
	local service

	for param in "${1}" "${2}" "${3}" "${4}" "${5}"
	do
		if (! echo "${param}" | grep "^[-]" &>/dev/null)
		then
			service="${param}"

			break
		else
			other_params="${other_params} ${param}"
		fi
	done

	if [ -n "${service}" ]
	then
		service=$(get_service ${service})
	fi

	docker-compose up --remove-orphans ${other_params} ${service}
}

function execute_command {
	if [[ $(type -t "command_${1}") == "function" ]]
	then
		command_${1} "${2}" "${3}" "${4}"
	else
		cd "builds/deploy"

		docker-compose ${@}
	fi
}

function get_service {
	local services=$(docker-compose config --services | grep "${1}")
	local count=$(echo "${services}" | wc -w)

	if [ "${count}" -eq 1 ]
	then
		echo "${services}"
	elif [ ${count} -eq 0 ]
	then
		echo "Couldn't find any running services with this name." >&2

		exit 1
	else
		echo "Found more services with the give name, specify name correctly:" >&2
		echo "${services}" >&2

		exit 1
	fi
}

function go_to_folder {
	local script_path=$(readlink /proc/$$/fd/255 2>/dev/null)

	cd $(dirname "${script_path}")

}

function main {
	go_to_folder

	check_usage ${@}

	execute_command ${@}
}

main ${@}