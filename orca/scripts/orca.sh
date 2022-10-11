#!/bin/bash

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: orca <command>"
		echo ""
		echo "Available commands:"
		echo "    all: Build as \"latest\" and deploy automatically"
		echo "    build: Call build_services.sh"
		echo "    force_primary: Change the database server configuration and make the current server the primary. Only use this in emergencies and on the node which was last written by the cluster."
		echo "    install: Install this script"
		echo "    mysql: Log into database server on this host"
		echo "    setup_shared_volume: Enable GlusterFS and create the necessary mount point for the shared volume"
		echo "    ssh <service>: Log in to the service's container"
		echo "    unseal: Unseal the vault operator"
		echo "    up: Validate the configuration and start the services with \"docker-compose up\""
		echo ""
		echo "All other commands are executed as docker-compose commands from the correct directory."
		echo ""
		echo "This script reads the following environment variables:"
		echo ""
		echo "    ORCA_DB_BOOTSTRAP (optional): Set this to yes to start a new database cluster"
		echo "    ORCA_DB_SKIP_WAIT (optional): Set this to true if the database container should start without waiting for others"
		echo ""
		echo "Examples:"
		echo ""
		echo "    orca ps: Show the list of running services"
		echo "    orca up -d liferay: Start the Liferay service in the background"

		exit 1
	fi
}

function command_all {
	command_build latest

	command_deploy latest
}

function command_backup {
	cd builds/deploy

	docker-compose exec backup /usr/local/bin/backup.sh
}

function command_build {
	scripts/build_services.sh ${@}
}

function command_deploy {
	cd builds

	ln -fs ${1} deploy
}

function command_force_primary {
	sed -i "s/safe_to_bootstrap: 0/safe_to_bootstrap: 1/" /opt/liferay/db-data/data/grastate.dat
}

function command_install {
	echo "#!/bin/bash" > "/usr/local/bin/orca"
	echo "" >> "/usr/local/bin/orca"
	echo "$(pwd)/scripts/orca.sh \${@}" >> "/usr/local/bin/orca"

	chmod a+x "/usr/local/bin/orca"
}

function command_mysql {
	cd builds/deploy

	docker-compose exec db /usr/local/bin/connect_to_mysql.sh
}

function command_setup_shared_volume {
	if [ ! -e "/opt/gluster-data/gv0" ]
	then
		echo "To set up the shared volume, the /opt/gluster-data/gv0 directory must exist on the host. It should be a separate volume formatted with XFS."

		return
	fi

	systemctl enable glusterd
	systemctl start glusterd

	mkdir -p /opt/liferay/shared-volume

	echo "$(hostname):/gv0 /opt/liferay/shared-volume glusterfs defaults 0 0" >> /etc/fstab
}

function command_ssh {
	cd builds/deploy

	docker-compose exec ${1} /bin/bash
}

function command_unseal {
	cd builds/deploy

	docker-compose exec vault /usr/bin/vault operator unseal
}

function command_up {
	if ( ! scripts/validate_environment.sh )
	then
		exit 1
	fi

	if [ -d /opt/liferay/tokens ]
	then
		for token in $(ls /opt/liferay/tokens)
		do
			echo "Setting the ${token} token."

			export ORCA_VAULT_TOKEN_${token}=$(cat /opt/liferay/tokens/${token})
		done
	fi

	cd builds/deploy

	docker-compose up ${@}
}

function execute_command {
	if [[ $(type -t "command_${1}") == "function" ]]
	then
		command_${1} "${2}" "${3}" "${4}"
	else
		echo "Unrecognized command for Orca ($1), passing to docker-compose..."

		cd builds/deploy

		docker-compose ${@}
	fi
}

function main {
	cd $(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/../

	check_usage ${@}

	execute_command ${@}
}

main ${@}