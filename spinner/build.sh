#!/bin/bash

source ../_liferay_common.sh

function build_service_antivirus {
	write "    antivirus:"

	write_deploy_section 4G

	local antivirus_image=$(grep "\"image\": " "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/antivirus/LCP.json | sed -e "s/.*image\": \""// | sed -e "s/\",$//")

	write "        image: ${antivirus_image}"

	write "        ports:"
	write "            - \"${ANTIVIRUS_PORT}:3310\""
}

function build_service_database {
	write "    database:"
	write "        command: mysqld --character-set-filesystem=utf8mb4 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci --default-authentication-plugin=mysql_native_password --max_allowed_packet=256M --tls-version=''"

	write_deploy_section 1G

	write "        environment:"
	write "            - MYSQL_DATABASE=lportal"
	write "            - MYSQL_PASSWORD=password"
	write "            - MYSQL_ROOT_HOST=%"
	write "            - MYSQL_ROOT_PASSWORD=password"
	write "            - MYSQL_USER=dxpcloud"
	write "        image: mysql:8.0.32"
	write "        ports:"
	write "            - ${OPEN_PORT_ON}${DATABASE_PORT}:3306"
	write "        volumes:"
	write "            - ./database_import:/docker-entrypoint-initdb.d"
	write "            - mysql-db:/var/lib/mysql"
}

function build_service_liferay {
	mkdir -p build/liferay/resources/opt/liferay

	cp ../../orca/templates/liferay/resources/opt/liferay/cluster-link-tcp.xml build/liferay/resources/opt/liferay

	mkdir -p build/liferay/resources/usr/local/bin

	cp ../../orca/templates/liferay/resources/usr/local/bin/remove_lock_on_startup.sh build/liferay/resources/usr/local/bin

	mkdir -p build/liferay/resources/usr/local/liferay/scripts/pre-startup

	cp ../../orca/templates/liferay/resources/usr/local/liferay/scripts/pre-startup/10_wait_for_dependencies.sh build/liferay/resources/usr/local/liferay/scripts/pre-startup

	(
		echo "FROM $(grep -e '^liferay.workspace.docker.image.liferay=' "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/gradle.properties" | cut -d'=' -f2)"

		echo "COPY resources/opt/liferay /opt/liferay"
		echo "COPY resources/usr/local/bin /usr/local/bin"
		echo "COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts"

		cat "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/Dockerfile.ext"
	) > build/liferay/Dockerfile

	mkdir -p liferay_mount/files/deploy

	cp -r ../dxp-activation-key/*.xml liferay_mount/files/deploy

	cp -r "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/liferay/configs/common/* liferay_mount/files
	cp -r "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/liferay/configs/"${LXC_ENVIRONMENT}"/* liferay_mount/files

	echo "Deleting the following files from the DXP configuration so it can run locally:"
	echo ""

	for file in \
		osgi/configs/com.liferay.portal.k8s.agent.configuration.PortalK8sAgentConfiguration.config \
		osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config \
		osgi/configs/com.liferay.portal.security.sso.openid.connect.configuration.OpenIdConnectConfiguration.config \
		osgi/configs/com.liferay.portal.security.sso.openid.connect.internal.configuration.OpenIdConnectProviderConfiguration_liferayokta.config \
		tomcat/webapps/ROOT/WEB-INF/classes/META-INF/portal-log4j-ext.xml
	do
		rm -f "liferay_mount/files/${file}"

		echo "    ${file}"
	done

	echo ""

	mkdir -p liferay_mount/files/patching
	mkdir -p liferay_mount/files/scripts

	mv liferay_mount/files/patching liferay_mount
	mv liferay_mount/files/scripts liferay_mount

	(
		echo "active=B\"true\""
		echo "maxUsers=I\"0\""
		echo "mx=\"spinner-test.com\""
		echo "siteInitializerKey=\"\""
		echo "virtualHostname=\"spinner-test.com\""
	) >> "liferay_mount/files/osgi/configs/com.liferay.portal.instances.internal.configuration.PortalInstancesConfiguration~spinner-test.com.config"

	for index in $(seq 1 ${NUMBER_OF_LIFERAY_NODES})
	do
		local port_last_digit=$((index - 1))

		write "    liferay-${index}:"
		write "        build: ./build/liferay"

		write_deploy_section 6G

		write "        environment:"
		write "            - LCP_LIFERAY_UPGRADE_ENABLED=\${LCP_LIFERAY_UPGRADE_ENABLED:-}"
		write "            - LCP_SECRET_DATABASE_HOST=database"
		write "            - LCP_SECRET_DATABASE_PASSWORD=password"
		write "            - LCP_SECRET_DATABASE_USER=root"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS="
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_CONTROL=control-channel-liferay-${index}"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_TRANSPORT_PERIOD_NUMBER0=transport-channel-logic-${index}"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL=/opt/liferay/cluster-link-tcp.xml"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD__NUMBER0_=/opt/liferay/cluster-link-tcp.xml"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_ENABLED=true"
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_CLUSTER_UPPERCASEN_AME=\"liferay_cluster\""
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_NETWORK_UPPERCASEH_OST_UPPERCASEA_DDRESSES=\"search:9200\""
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_OPERATION_UPPERCASEM_ODE=\"REMOTE\""
		write "            - LIFERAY_CONFIGURATION_PERIOD_OVERRIDE_PERIOD_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SEARCH_PERIOD_ELASTICSEARCH_NUMBER7__PERIOD_CONFIGURATION_PERIOD__UPPERCASEE_LASTICSEARCH_UPPERCASEC_ONFIGURATION_UNDERLINE_PRODUCTION_UPPERCASEM_ODE_UPPERCASEE_NABLED=B\"true\""
		write "            - LIFERAY_DISABLE_TRIAL_LICENSE=true"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_DRIVER_UPPERCASEC_LASS_UPPERCASEN_AME=org.mariadb.jdbc.Driver"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD=password"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_URL=jdbc:mysql://database/lportal?characterEncoding=UTF-8&dontTrackOpenResources=true&holdResultsOpenOverStatementClose=true&serverTimezone=GMT&useFastDateParsing=false&useUnicode=true&useSSL=false"
		write "            - LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=root"
		write "            - LIFERAY_JPDA_ENABLED=true"
		write "            - LIFERAY_SETUP_PERIOD_DATABASE_PERIOD_JAR_PERIOD_SHA_NUMBER1__OPENBRACKET_COM_PERIOD_MYSQL_PERIOD_CJ_PERIOD_JDBC_PERIOD__UPPERCASED_RIVER_CLOSEBRACKET_=6d6ea84c870837afa63f5f55efde211a84cf2897"
		write "            - LIFERAY_SETUP_PERIOD_DATABASE_PERIOD_JAR_PERIOD_URL_OPENBRACKET_COM_PERIOD_MYSQL_PERIOD_CJ_PERIOD_JDBC_PERIOD__UPPERCASED_RIVER_CLOSEBRACKET_=https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/2.7.4/mariadb-java-client-2.7.4.jar"
		write "            - LIFERAY_UPGRADE_ENABLED=false"
		write "            - LIFERAY_USERS_PERIOD_REMINDER_PERIOD_QUERIES_PERIOD_ENABLED=false"
		write "            - LIFERAY_WEB_PERIOD_SERVER_PERIOD_PROTOCOL=http"
		write "            - LIFERAY_WORKSPACE_ENVIRONMENT=${LXC_ENVIRONMENT}"
		write "            - LOCAL_STACK=true"
		write "            - ORCA_LIFERAY_SEARCH_ADDRESSES=search:9200"

		if [ -n "${LOCAL_NETWORK_ENABLED}" ]
		then
			write "            - LIFERAY_VIRTUAL_PERIOD_HOSTS_PERIOD_VALID_PERIOD_HOSTS=*"
		fi

		write "        hostname: liferay-${index}"
		write "        ports:"
		write "            - ${OPEN_PORT_ON}1800${port_last_digit}:8000"
		write "            - ${OPEN_PORT_ON}1808${port_last_digit}:8080"
		write "        volumes:"
		write "            - liferay-document-library:/opt/liferay/data"
		write "            - ./liferay_mount:/mnt/liferay"
	done
}

function build_service_search {
	mkdir -p build/search

	grep -v "^FROM" ../../orca/templates/search/Dockerfile | sed -e "s/#FROM/FROM/" > build/search/Dockerfile

	write "    search:"
	write "        build: ./build/search"

	write_deploy_section 2G

	write "        environment:"
	write "            - discovery.type=single-node"
	write "            - xpack.ml.enabled=false"
	write "            - xpack.monitoring.enabled=false"
	write "            - xpack.security.enabled=false"
	write "            - xpack.sql.enabled=false"
	write "            - xpack.watcher.enabled=false"
}

function build_service_web_server {

	#
	# Copy from the web server Docker image
	#

	local web_server_dir="${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}"/webserver

	local web_server_image=$(head -n 1 "${web_server_dir}"/Dockerfile)

	web_server_image=${web_server_image##* }

	docker pull --quiet "${web_server_image}" >/dev/null

	local web_server_container=$(docker create "${web_server_image}")

	mkdir -p build/web-server/resources/usr/local/etc/haproxy

	docker cp "${web_server_container}":/usr/local/etc/haproxy/haproxy.cfg build/web-server/resources/usr/local/etc/haproxy/haproxy.cfg

	sed -i build/web-server/resources/usr/local/etc/haproxy/haproxy.cfg -e "s/server-template.*/balance roundrobin\n\toption httpchk\n\tserver s1 liferay-1:8080 check/"

	docker rm "${web_server_container}" >/dev/null

	#
	# Copy from the OWASP Docker image
	#

	if [ -n "${MOD_SECURITY_ENABLED}" ]
	then
		docker pull --quiet owasp/modsecurity-crs:nginx >/dev/null

		local owasp_container=$(docker create owasp/modsecurity-crs:nginx)

		mkdir -p build/web-server/resources/etc/nginx/modsec

		docker cp "${owasp_container}":/etc/modsecurity.d/owasp-crs/crs-setup.conf build/web-server/resources/etc/nginx/modsec
		docker cp "${owasp_container}":/etc/modsecurity.d/owasp-crs/rules build/web-server/resources/etc/nginx/modsec

		docker rm "${owasp_container}" >/dev/null

		echo "Include /etc/nginx/modsec/rules/*.conf" > build/web-server/resources/etc/nginx/modsec/owasp-crs-rules.conf
	fi

	#
	# Copy from liferay-lxc
	#

	mkdir -p web-server_mount/configs

	cp -a "${web_server_dir}"/configs/* web-server_mount/configs

	sed -i web-server_mount/configs/common/nginx.conf -e "s/access_log.*/access_log off;/"

	echo "Deleting the following files from the web server configuration so it can run locally:"
	echo ""

	for file in \
		blocks.d/oauth2_proxy_pass.conf \
		blocks.d/oauth2_proxy_protection.conf \
		http.conf.d/admin.conf \
		scripts/01-whitelist_github_ips.sh
	do
		rm -f "web-server_mount/configs/common/${file}"

		echo "    ${file}"
	done

	echo ""

	(
		head -n 1 "${web_server_dir}"/Dockerfile

		echo ""
		echo "COPY resources/usr/local /usr/local"
		echo ""
		echo "ENV ERROR_LOG_LEVEL=warn"
		echo "ENV LCP_PROJECT_ENVIRONMENT=local"
		echo "ENV LCP_WEBSERVER_GLOBAL_TIMEOUT=1h"
		echo "ENV LCP_WEBSERVER_PROXY_MAX_TEMP_FILE_SIZE=0"

		if [ -n "${MOD_SECURITY_ENABLED}" ]
		then
			echo "ENV LCP_WEBSERVER_MODSECURITY=On"
			echo "ENV NGINX_MODSECURITY_MODE=on"
		else
			echo "ENV NGINX_MODSECURITY_MODE=off"
		fi

		echo "ENV PROXY_ADDRESS=127.0.0.1:81"

	) > build/web-server/Dockerfile

	write "    web-server:"
	write "        build: ./build/web-server"

	write_deploy_section 1G

	write "        ports:"
	write "            - ${OPEN_PORT_ON}${WEB_SERVER_PORT}:80"
	write "        volumes:"
	write "            - ./web-server_mount:/lcp-container"
}

function build_services {
	lc_cd "${STACK_DIR}"

	write "services:"

	build_service_antivirus
	build_service_database
	build_service_liferay
	build_service_search
	build_service_web_server

	write "volumes:"
	write "    liferay-document-library:"
	write "    mysql-db:"
}

function check_usage {
	lc_check_utils docker

	ANTIVIRUS_PORT=3310
	DATABASE_IMPORT=
	DATABASE_PORT=13306
	LXC_ENVIRONMENT=
	NUMBER_OF_LIFERAY_NODES=2
	OPEN_PORT_ON=127.0.0.1:
	WEB_SERVER_PORT=80

	while [ "${1}" != "" ]
	do
		case ${1} in
			-d)
				shift

				DATABASE_IMPORT=${1}

				;;
			-h)
				print_help

				;;
			-l)
				LOCAL_NETWORK_ENABLED=true
				OPEN_PORT_ON=""

				;;
			-m)
				MOD_SECURITY_ENABLED=true

				;;
			-n)
				shift

				NUMBER_OF_LIFERAY_NODES=${1}

				;;
			-o)
				shift

				STACK_NAME=env-${1}

				;;
			-r)
				ANTIVIRUS_PORT=$((RANDOM % 100 + 3300))
				DATABASE_PORT=$((RANDOM % 100 + 13300))
				WEB_SERVER_PORT=$((RANDOM % 100 + 80))

				echo "Antivirus port: ${ANTIVIRUS_PORT}"
				echo "Database port: ${DATABASE_PORT}"
				echo "Web Server port: ${WEB_SERVER_PORT}"

				;;
			-s)
				shift

				DATABASE_SKIP_TABLE=${1}

				;;
			*)
				LXC_ENVIRONMENT=${1}

				;;
		esac

		shift
	done

	if [ ! -n "${LXC_ENVIRONMENT}" ]
	then
		LXC_ENVIRONMENT=x1e4prd

		echo "Using LXC environment \"x1e4prd\" because the LXC environment was not set."
		echo ""
	fi

	lc_cd "$(dirname "$0")"

	if [ ! -n "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}" ]
	then
		SPINNER_LIFERAY_LXC_REPOSITORY_DIR=$(pwd)"/../../liferay-lxc"
	fi

	if [ ! -e "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}" ]
	then
		echo "The ${SPINNER_LIFERAY_LXC_REPOSITORY_DIR} directory does not exist. Clone the liferay-lxc repository to this directory or set the environment variable \"SPINNER_LIFERAY_LXC_REPOSITORY_DIR\" to point to an existing clone."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ ! -e "${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/configs/${LXC_ENVIRONMENT}" ]
	then
		echo "The ${SPINNER_LIFERAY_LXC_REPOSITORY_DIR}/liferay/configs/${LXC_ENVIRONMENT} directory does not exist."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [[ $(find dxp-activation-key -name "*.xml" | wc -l ) -eq 0 ]]
	then
		echo ""
		echo "Copy a valid DXP license to the dxp-activation-key directory before running this script."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	if [ ! -n "${STACK_NAME}" ]
	then
		STACK_NAME="env-${LXC_ENVIRONMENT}-"$(date +%s)
	fi

	STACK_DIR=$(pwd)/${STACK_NAME}

	if [ -e "${STACK_DIR}" ]
	then
		echo ""
		echo "The directory ${STACK_DIR} already exists."

		exit "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	mkdir -p "${STACK_DIR}"
}

function main {
	check_usage "${@}"

	(
		build_services

		prepare_database_import

		print_docker_compose_usage
	) | tee -a "${STACK_DIR}/README.txt"
}

function prepare_database_import {
	mkdir -p database_import

	if [ ! -n "${DATABASE_IMPORT}" ]
	then
		return
	fi

	echo ""
	echo "Preparing to import ${DATABASE_IMPORT}."

	lc_cd "${STACK_DIR}"/database_import

	cp "${DATABASE_IMPORT}" .

	if [ $(find . -type f -name "*.gz" | wc -l) -gt 0 ]
	then
		echo ""
		echo "Extracting the database import file."

		gzip -d $(find . -type f -name "*.gz") 
	fi

	mv $(find . -type f) 01_database.sql

	if [ -n "${DATABASE_SKIP_TABLE}" ]
	then
		echo ""
		echo "Removing ${DATABASE_SKIP_TABLE} from the database import."

		grep -v "^INSERT INTO .${DATABASE_SKIP_TABLE}. VALUES (" < 01_database.sql > 01_database_removed.sql

		rm 01_database.sql

		mv 01_database_removed.sql 01_database.sql
	fi

	echo ""
	echo "Adding 10_after_import.sql to make changes to the database. Review them before starting the container."

	echo "update VirtualHost SET hostname=concat(hostname, \".local\");" > 10_after_import.sql
}

function print_docker_compose_usage {
	echo "The stack configuration is ready to use. It is available in the ${STACK_NAME} directory. Use the following commands to start all services:"
	echo ""
	echo "    cd ${STACK_NAME}"
	echo ""
	echo "    $(lc_docker_compose) up -d antivirus database search web-server"
	echo ""
	echo "    $(lc_docker_compose) up liferay-1"
	echo ""
	echo "Use the following command to start the second Liferay node to test clustering:"
	echo ""
	echo "    $(lc_docker_compose) up liferay-2"
	echo ""
	echo "See https://liferay.atlassian.net/l/cp/SD571mFA for more information on how to debug."
}

function print_help {
	echo "Usage: ${0} <lxc-environment> -d <database-import>"
	echo ""
	echo "The script can be configured with the following arguments:"
	echo ""
	echo "    -d (optional): Set the database import file (raw or with a .gz suffix). Virtual hosts will be suffixed with .local (e.g. abc.liferay.com becomes abc.liferay.com.local)."
	echo "    -l (optional): Exported ports listen on all network interfaces."
	echo "    -m (optional): Enable mod_security on the web server with the rules from OWASP Top 10."
	echo "    -n (optional): Max number of clusters."
	echo "    -o (optional): Set directory name where the stack configuration will be created. It will be prefixed with \"env-\"."
	echo "    -r (optional): Randomize the MySQL, antivirus and web server ports opened on localhost to enable multiple servers at the same time."
	echo "    -s (optional): Skip the specified table name in the database import"
	echo ""
	echo "The default LXC environment is \"x1e4prd\"."
	echo ""
	echo "Example: ${0} x1e4prd -d sql.gz -o test"

	exit "${LIFERAY_COMMON_EXIT_CODE_HELP}"
}

function write {
	echo "${1}" >> docker-compose.yml
}

function write_deploy_section {
	write "        deploy:"
	write "            resources:"
	write "                limits:"
	write "                    memory: ${1}"
	write "                reservations:"
	write "                    memory: ${1}"
}

main "${@}"