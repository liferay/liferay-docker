#!/bin/bash

set -e

function add_secrets {
	compose_add 0 "secrets:"

	local secret_dir=$(get_config .configuration.secret_dir /opt/liferay/shared-volume/secrets)

	for secret in sql_backup_password sql_liferay_password sql_root_password
	do
		local secret_file="${secret_dir}/${secret}.txt"

		if [ ! -e "${secret_file}" ]
		then
			pwgen -1s 24 > ${secret_file}
			chmod 600 ${secret_file}
		fi

		compose_add 1 "${secret}:"
		compose_add 1 "    file: ${secret_file}"
	done
}

function add_services {
	compose_add 0 "services:"

	if [ ! -n "${HOST}" ]
	then
		HOST=$(hostname)
	fi

	local host_config=$(get_config ".hosts.${HOST}")

	if [ ! -n "${host_config}" ]
	then
		HOST="localhost"
		host_config=$(get_config ".hosts.${HOST}")

		if [ ! -n "${host_config}" ]
		then
			echo "Couldn't find a matching host in the configuration. Set the HOST environment variable."

			exit 1
		fi
	fi

	for SERVICE in $(yq ".hosts.${HOST}.services" < "${CONFIG_FILE}" | grep -v '  .*' | sed 's/-[ ]//' | sed 's/:.*//')
	do
		local service_template="${SERVICE}"

		SERVICE="${SERVICE}-${HOST}"

		echo "Building ${SERVICE}."

		build_${service_template}
	done
}

function build_antivirus {
	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: clamav/clamav:0.105"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"3310:3310\""
}

function build_backup {
	docker build \
		--tag "backup:${VERSION}" \
		"templates/backup"

	local db_addresses=$(find_services db host_port "3306")

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "        - LIFERAY_BACKUP_CRON_EXPRESSION=0 */4 * * *"
	compose_add 1 "        - LIFERAY_DB_ADDRESSES=${db_addresses}"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: backup:${VERSION}"
	compose_add 1 "    secrets:"
	compose_add 1 "        - sql_root_password"
	compose_add 1 "    volumes:"
	compose_add 1 "        - /opt/liferay/backups:/opt/liferay/backups"
	compose_add 1 "        - /opt/liferay/shared-volume:/opt/liferay/shared-volume"

}

function build_db {
	docker build \
		--tag "db:${VERSION}" \
		"templates/db"

	local cluster_addresses=$(find_services db host_port 4567 true)
	local db_addresses=$(find_services db host_port 3306 true)
	local host_ip=$(get_config ".hosts.${HOST}.ip" ${SERVICE})

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "        - LIFERAY_DB_ADDRESSES=${db_addresses}"
	compose_add 1 "        - LIFERAY_DB_SKIP_WAIT=\${LIFERAY_DB_SKIP_WAIT:-}"
	compose_add 1 "        - MARIADB_GALERA_CLUSTER_BOOTSTRAP=\${LIFERAY_DB_BOOTSTRAP:-}"
	compose_add 1 "        - MARIADB_GALERA_CLUSTER_ADDRESS=gcomm://${cluster_addresses}"
	compose_add 1 "        - MARIADB_GALERA_CLUSTER_NAME=liferay-db"
	compose_add 1 "        - MARIADB_GALERA_MARIABACKUP_PASSWORD_FILE=/run/secrets/sql_backup_password"
	compose_add 1 "        - MARIADB_GALERA_MARIABACKUP_USER=orca_mariabackup"
	compose_add 1 "        - MARIADB_GALERA_NODE_ADDRESS=${host_ip}"
	compose_add 1 "        - MARIADB_DATABASE=lportal"
	compose_add 1 "        - MARIADB_EXTRA_FLAGS=--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --wsrep_provider_options=ist.recv_addr=${host_ip}:4568;ist.recv_bind=0.0.0.0:4568 --wsrep_node_incoming_address=${host_ip} --wsrep_sst_receive_address=${host_ip}"
	compose_add 1 "        - MARIADB_PASSWORD_FILE=/run/secrets/sql_liferay_password"
	compose_add 1 "        - MARIADB_ROOT_HOST=localhost"
	compose_add 1 "        - MARIADB_ROOT_PASSWORD_FILE=/run/secrets/sql_root_password"
	compose_add 1 "        - MARIADB_USER=lportal"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: db:${VERSION}"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"3306:3306\""
	compose_add 1 "        - \"4444:4444\""
	compose_add 1 "        - \"4567:4567\""
	compose_add 1 "        - \"4568:4568\""
	compose_add 1 "    secrets:"
	compose_add 1 "        - sql_backup_password"
	compose_add 1 "        - sql_liferay_password"
	compose_add 1 "        - sql_root_password"
	compose_add 1 "    volumes:"
	compose_add 1 "        - /opt/liferay/db-data:/bitnami/mariadb"
}

function build_liferay {
	if [ -e "config/liferay-license.xml" ]
	then
		mkdir -p "templates/liferay/resources/opt/liferay/deploy/"
		cp "config/liferay-license.xml" "templates/liferay/resources/opt/liferay/deploy/license.xml"
	else
		echo "ERROR: Copy a valid Liferay DXP license to config/liferay-license.xml before running this script."

		exit 1
	fi

	docker build \
		--tag "liferay:${VERSION}" \
		"templates/liferay"

	local antivirus_address=$(find_services antivirus host_port 3310)
	local db_address=$(get_config ".hosts.${HOST}.configuration.liferay.db" "db-${HOST}")
	local host_ip=$(get_config ".hosts.${HOST}.ip" ${SERVICE})
	local liferay_addresses=$(find_services liferay host_port 8080 true)
	local search_addresses=$(find_services search host_port 9200)

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "        - LIFERAY_ANTIVIRUS_ADDRESS=${antivirus_address}"

	if [ -n "${liferay_addresses}" ]
	then
		compose_add 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED=true"
		compose_add 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_CONTROL=control-channel-${SERVICE}"
		compose_add 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_TRANSPORT_PERIOD_NUMBER0=transport-channel-logic-${SERVICE}"
		compose_add 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL=/opt/liferay/cluster-link-tcp.xml"
		compose_add 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD__NUMBER0_=/opt/liferay/cluster-link-tcp.xml"
		compose_add 2 "    - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS="
	fi

	compose_add 1 "        - LIFERAY_DISABLE_TRIAL_LICENSE=true"
	compose_add 1 "        - LIFERAY_DL_PERIOD_STORE_PERIOD_ANTIVIRUS_PERIOD_ENABLED=true"
	compose_add 1 "        - LIFERAY_DL_PERIOD_STORE_PERIOD_IMPL=com.liferay.portal.store.file.system.AdvancedFileSystemStore"
	compose_add 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME=org.mariadb.jdbc.Driver"
	compose_add 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE=/run/secrets/sql_liferay_password"
	compose_add 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL=jdbc:mariadb://${db_address}/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&serverTimezone=GMT&useFastDateParsing=false&useUnicode=true&useSSL=false"
	compose_add 1 "        - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=lportal"
	compose_add 1 "        - LIFERAY_JVM_OPTS=-Djgroups.bind_addr=${SERVICE} -Djgroups.external_addr=${host_ip}"
	compose_add 1 "        - LIFERAY_SEARCH_ADDRESSES=${search_addresses}"
	compose_add 1 "        - LIFERAY_SETUP_PERIOD_DATABASE_PERIOD_JAR_PERIOD_URL_OPENBRACKET_COM_PERIOD_MYSQL_PERIOD_CJ_PERIOD_JDBC_PERIOD__UPPERCASED_RIVER_CLOSEBRACKET_=https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/3.0.4/mariadb-java-client-3.0.4.jar"
	compose_add 1 "        - LIFERAY_TOMCAT_AJP_PORT=8009"
	compose_add 1 "        - LIFERAY_TOMCAT_JVM_ROUTE=${SERVICE}"
	compose_add 1 "        - LIFERAY_WEB_PERIOD_SERVER_PERIOD_DISPLAY_PERIOD_NODE=true"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: liferay:${VERSION}"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"7800:7800\""
	compose_add 1 "        - \"7801:7801\""
	compose_add 1 "        - \"8009:8009\""
	compose_add 1 "        - \"8080:8080\""
	compose_add 1 "    secrets:"
	compose_add 1 "        - sql_liferay_password"
	compose_add 1 "    volumes:"
	compose_add 1 "        - /opt/liferay/shared-volume:/opt/liferay/shared-volume"
}

function build_logproxy {
	local logserver=$(find_services logserver host_port 514)

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    command: syslog+udp://${logserver}"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: gliderlabs/logspout"
	compose_add 1 "    volumes:"
	compose_add 1 "        - /var/run/docker.sock:/var/run/docker.sock"
}

function build_logserver {
	docker build \
		--tag "logserver:${VERSION}" \
		"templates/logserver"

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    command: -F --no-caps"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: logserver:${VERSION}"
	compose_add 1 "    ports:"
	compose_add 1 "        - 514:514/udp"
	compose_add 1 "    volumes:"
	compose_add 1 "        - /opt/liferay/shared-volume/logs:/var/log/syslogng/"
}

function build_search {
	docker build \
		--tag "search:${VERSION}" \
		"templates/search"

	local host_ip=$(get_config ".hosts.${HOST}.ip" ${SERVICE})
	local search_services_names=$(find_services search service_name)
	local seed_hosts=$(find_services search host_port 9300 true)

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "        - cluster.initial_master_nodes=${search_services_names}"
	compose_add 1 "        - cluster.name=liferay-search"
	compose_add 1 "        - discovery.seed_hosts=${seed_hosts}"
	compose_add 1 "        - network.publish_host=${host_ip}"
	compose_add 1 "        - node.name=${SERVICE}"
	compose_add 1 "        - xpack.ml.enabled=false"
	compose_add 1 "        - xpack.monitoring.enabled=false"
	compose_add 1 "        - xpack.security.enabled=false"
	compose_add 1 "        - xpack.sql.enabled=false"
	compose_add 1 "        - xpack.watcher.enabled=false"
	compose_add 1 "    healthcheck:"
	compose_add 1 "        interval: 40s"
	compose_add 1 "        retries: 3"
	compose_add 1 "        test: curl localhost:9200/_cat/health | grep green"
	compose_add 1 "        timeout: 5s"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: search:${VERSION}"
	compose_add 1 "    mem_limit: 8G"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"9200:9200\""
	compose_add 1 "        - \"9300:9300\""
}

function build_webserver {
	docker build \
		--tag "liferay-webserver:${VERSION}" \
		"templates/webserver"

	local balance_members=$(find_services liferay host_port 8009)

	compose_add 1 "${SERVICE}:"
	compose_add 1 "    container_name: ${SERVICE}"
	compose_add 1 "    environment:"
	compose_add 1 "        - LIFERAY_BALANCE_MEMBERS=${balance_members}"
	compose_add 1 "    hostname: ${SERVICE}"
	compose_add 1 "    image: liferay-webserver:${VERSION}"
	compose_add 1 "    ports:"
	compose_add 1 "        - \"80:80\""
}

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <version>"
		echo ""
		echo "The script reads the following environment variables:"
		echo ""
		echo "    LIFERAY_ORCA_CONFIG (optional): Set the name of the configuration you would like to use. If not set the \"production\" is used."
		echo "    LIFERAY_ORCA_HOST (optional): Set the name of the host you for which to generate the services. If not set the hostname is used."
		echo ""
		echo "Set the version number of the generated images as the first parameter to build the images and configuration."
		echo ""
		echo "Example: ${0} 1.0.0"

		exit 1
	fi

	CONFIG="${LIFERAY_ORCA_CONFIG}"
	HOST="${LIFERAY_ORCA_HOST}"
	VERSION="${1}"

	check_utils docker docker-compose pwgen yq
}

function check_utils {

	#
	# https://stackoverflow.com/a/677212
	#

	for util in "${@}"
	do
		command -v "${util}" >/dev/null 2>&1 || { echo >&2 "The utility ${util} is not installed."; exit 1; }
	done
}

function compose_add {
	if [ ${1} -eq 0 ]
	then
		echo "${2}" >> ${COMPOSE_FILE}

		return
	fi

	local line=""

	for i in $(seq ${1})
	do
		line="${line}    "
	done

	line="${line}${2}"

	echo "${line}" >> ${COMPOSE_FILE}
}

function create_compose_file {
	BUILD_DIR="builds/${VERSION}"
	COMPOSE_FILE="${BUILD_DIR}/docker-compose.yml"

	mkdir -p "${BUILD_DIR}"

	if [ -e "${COMPOSE_FILE}" ]
	then
		rm -f "${COMPOSE_FILE}"
	fi
}

function get_config {
	local yq_output=$(yq ${1} < ${CONFIG_FILE})

	if [ "${yq_output}" == "null" ]
	then
		echo "${2}"
	else
		echo "${yq_output}"
	fi
}

function find_services {
	local search_for="${1}"
	local template="${2}"
	local postfix="${3}"
	local exclude_this_host="${4}"

	local list

	for host in $(yq ".hosts" < ${CONFIG_FILE} | grep -v '  .*' | sed 's/-[ ]//' | sed 's/:.*//')
	do
		if [ "${exclude_this_host}" == "true" ] && [ "${host}" == "${HOST}" ]
		then
			continue
		fi

		for service in $(yq ".hosts.${host}.services" < "${CONFIG_FILE}" | grep -v '  .*' | sed 's/-[ ]//' | sed 's/:.*//')
		do
			if [ "${service}" == "${search_for}" ]
			then
				local add_item

				if [ "${template}" == "service_name" ]
				then
					add_item="${service}-${host}"
				elif [ "${template}" == "host_port" ]
				then
					if [ "${host}" == "localhost" ] || [ "${host}" == "${HOST}" ]
					then
						add_item="${service}-${host}:${postfix}"
					else
						local host_ip=$(get_config ".hosts.${host}.ip" ${host})

						add_item="${host_ip}:${postfix}"
					fi
				fi

				if [ -n "${list}" ]
				then
					list="${list},${add_item}"
				else
					list="${add_item}"
				fi

			fi
		done
	done

	echo "${list}"
}

function main {
	check_usage ${@}

	setup_configuration

	create_compose_file

	add_secrets

	add_services
}

function setup_configuration {
	if [ ! -n "${CONFIG}" ]
	then
		CONFIG="production"
	fi
	if [ -e "config/${CONFIG}.yml" ]
	then
		CONFIG_FILE="config/${CONFIG}.yml"

		echo "Using configuration ${CONFIG_FILE}."
	else
		CONFIG_FILE="single_server.yml"

		echo "Using the default, single server configuration."
	fi
}

main ${@}