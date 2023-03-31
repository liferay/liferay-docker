#!/bin/bash

function check_usage {
	check_utils docker

	ENVIRONMENT=${1}

	if [ ! -n "${ENVIRONMENT}" ]
	then
		ENVIRONMENT=x1e4prd

		echo "Environment was not set, using x1e4prd."
	fi

	lcd "$(dirname "$0")"

	if [ ! -n "${LIFERAY_LXC_REPOSITORY_DIR}" ]
	then
		LIFERAY_LXC_REPOSITORY_DIR=$(pwd)"/../../liferay-lxc"
	fi

	if [ ! -e "${LIFERAY_LXC_REPOSITORY_DIR}" ]
	then
		echo "The ${LIFERAY_LXC_REPOSITORY_DIR} directory does not exist. Clone the liferay-lxc repository to this directory or set LIFERAY_LXC_REPOSITORY_DIR to point to an existing clone."

		exit 1
	fi

	if [ ! -e "${LIFERAY_LXC_REPOSITORY_DIR}/liferay/configs/${ENVIRONMENT}" ]
	then
		echo "Usage: ${0} <environment>"
		echo ""
		echo "By default the x1e4prd environment configuration is used."
		echo ""
		echo "Example: ${0} x1e4prd"

		exit 1
	fi

	if [[ $(find dxp-activation-key -name "*.xml" | wc -l ) -eq 0 ]]
	then
		echo "Copy a valid DXP license to the dxp-activation-key directory before running this script."

		exit 1
	fi

	STACK_NAME="env-${ENVIRONMENT}-"$(date +%s)
	STACK_DIR=$(pwd)/${STACK_NAME}

	mkdir -p "${STACK_DIR}"
}

function check_utils {
	for util in "${@}"
	do
		if (! command -v "${util}" &>/dev/null)
		then
			echo "The utility ${util} is not installed."

			exit 1
		fi
	done
}

function create_liferay_configuration {
	function delete_config {
		echo " - ${1}"

		rm -f "liferay_mount/files/${1}"
	}

	function write_company {
		echo "${1}" >> "liferay_mount/files/osgi/configs/com.liferay.portal.instances.internal.configuration.PortalInstancesConfiguration~spinner-test.com.config"
	}

	mkdir -p liferay_mount/files/deploy

	cp -r ../dxp-activation-key/*.xml liferay_mount/files/deploy

	cp -r "${LIFERAY_LXC_REPOSITORY_DIR}"/liferay/configs/common/* liferay_mount/files
	cp -r "${LIFERAY_LXC_REPOSITORY_DIR}"/liferay/configs/"${ENVIRONMENT}"/* liferay_mount/files

	echo "Deleting the following files from configuration to ensure DXP can run locally:"

	delete_config osgi/configs/com.liferay.portal.k8s.agent.configuration.PortalK8sAgentConfiguration.config
	delete_config osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config
	delete_config osgi/configs/com.liferay.portal.security.sso.openid.connect.configuration.OpenIdConnectConfiguration.config
	delete_config osgi/configs/com.liferay.portal.security.sso.openid.connect.internal.configuration.OpenIdConnectProviderConfiguration_liferayokta.config
	delete_config tomcat/webapps/ROOT/WEB-INF/classes/META-INF/portal-log4j-ext.xml

	mkdir -p liferay_mount/files/patching
	mkdir -p liferay_mount/files/scripts

	mv liferay_mount/files/patching liferay_mount
	mv liferay_mount/files/scripts liferay_mount

	write_company "active=B\"true\""
	write_company "maxUsers=I\"0\""
	write_company "mx=\"spinner-test.com\""
	write_company "siteInitializerKey=\"\""
	write_company "virtualHostname=\"spinner-test.com\""

}

function create_liferay_dockerfile {
	(
		echo "FROM $(grep -e '^liferay.workspace.docker.image.liferay=' "${LIFERAY_LXC_REPOSITORY_DIR}/liferay/gradle.properties" | cut -d'=' -f2)"

		echo "COPY resources/opt/liferay /opt/liferay/"
		echo "COPY resources/usr/local/bin /usr/local/bin/"
		echo "COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/"

		cat "${LIFERAY_LXC_REPOSITORY_DIR}/liferay/Dockerfile.ext"
	) > build/liferay/Dockerfile
}

function create_webserver_dockerfile {
	(
		echo $(head -n 1 ${LIFERAY_LXC_REPOSITORY_DIR}/webserver/Dockerfile)

		echo "COPY resources/etc/nginx /etc/nginx"
		echo "COPY resources/usr/local /usr/local"

	) > build/webserver/Dockerfile
}

function generate_configuration {
	function write {
		echo "${1}" >> docker-compose.yml
	}

	function write_deploy {
		write "        deploy:"
		write "            resources:"
		write "                limits:"
		write "                    memory: ${1}"
		write "                reservations:"
		write "                    memory: ${1}"
	}

	function write_liferay {
		write "    ${1}:"
		write "        build: ./build/liferay"

		write_deploy 6G

		write "        environment:"
		write "            - LCP_LIFERAY_UPGRADE_ENABLED=\${LCP_LIFERAY_UPGRADE_ENABLED:-}"
		write "            - LCP_SECRET_DATABASE_HOST=database"
		write "            - LCP_SECRET_DATABASE_PASSWORD=password"
		write "            - LCP_SECRET_DATABASE_USER=root"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_AUTODETECT_PERIOD_ADDRESS="
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_CONTROL=control-channel-${1}"
		write "            - LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_LOGIC_PERIOD_NAME_PERIOD_TRANSPORT_PERIOD_NUMBER0=transport-channel-logic-${1}"
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
		write "            - LIFERAY_WORKSPACE_ENVIRONMENT=${ENVIRONMENT}"
		write "            - LOCAL_STACK=true"
		write "            - ORCA_LIFERAY_SEARCH_ADDRESSES=search:9200"
		write "        hostname: ${1}"
		write "        ports:"
		write "            - 127.0.0.1:1800${2}:8000"
		write "            - 127.0.0.1:1808${2}:8080"
		write "        volumes:"
		write "            - liferay-document-library:/opt/liferay/data"
		write "            - ./liferay_mount:/mnt/liferay"
	}


	lcd "${STACK_DIR}"

	mkdir -p build/liferay/resources/opt/liferay
	cp ../../orca/templates/liferay/resources/opt/liferay/cluster-link-tcp.xml build/liferay/resources/opt/liferay

	mkdir -p build/liferay/resources/usr/local/bin
	cp ../../orca/templates/liferay/resources/usr/local/bin/remove_lock_on_startup.sh build/liferay/resources/usr/local/bin

	mkdir -p build/liferay/resources/usr/local/liferay/scripts/pre-startup
	cp ../../orca/templates/liferay/resources/usr/local/liferay/scripts/pre-startup/10_wait_for_dependencies.sh build/liferay/resources/usr/local/liferay/scripts/pre-startup
	cp ../../orca/templates/liferay/resources/usr/local/liferay/scripts/pre-startup/99_startup_lock.sh build/liferay/resources/usr/local/liferay/scripts/pre-startup

	mkdir -p build/search/
	grep -v "^FROM" ../../orca/templates/search/Dockerfile | sed -e "s/#FROM/FROM/" > build/search/Dockerfile

	mkdir -p database_import

	mkdir -p build/webserver/resources/etc/nginx
	cp -a ${LIFERAY_LXC_REPOSITORY_DIR}/webserver/configs/common/blocks.d/ build/webserver/resources/etc/nginx
	rm -f build/webserver/resources/etc/nginx/blocks.d/oauth2_proxy_pass.conf
	rm -f build/webserver/resources/etc/nginx/blocks.d/oauth2_proxy_protection.conf

	cp -a ${LIFERAY_LXC_REPOSITORY_DIR}/webserver/configs/common/conf.d/ build/webserver/resources/etc/nginx
	cp -a ${LIFERAY_LXC_REPOSITORY_DIR}/webserver/configs/common/public/ build/webserver/resources/etc/nginx
	cp ../resources/webserver/etc/nginx/nginx.conf build/webserver/resources/etc/nginx

	mkdir -p build/webserver/resources/etc/usr
	cp -a ../resources/webserver/usr/ build/webserver/resources/usr

	create_liferay_dockerfile

	create_liferay_configuration

	create_webserver_dockerfile

	write "services:"
	write "    antivirus:"

	write_deploy 1G

	write "        image: clamav/clamav:1.0.1-1"
	write "        ports:"
	write "            - \"3310:3310\""
	write "    database:"
	write "        command: mysqld --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci --character-set-filesystem=utf8mb4 --default-authentication-plugin=mysql_native_password --max_allowed_packet=256M --tls-version=''"

	write_deploy 1G

	write "        environment:"
	write "            - MYSQL_DATABASE=lportal"
	write "            - MYSQL_PASSWORD=password"
	write "            - MYSQL_ROOT_HOST=%"
	write "            - MYSQL_ROOT_PASSWORD=password"
	write "            - MYSQL_USER=dxpcloud"
	write "        image: mysql:8.0.32"
	write "        ports:"
	write "            - 127.0.0.1:13306:3306"
	write "        volumes:"
	write "            - ./database_import:/docker-entrypoint-initdb.d"
	write "            - mysql-db:/var/lib/mysql"

	write_liferay liferay-1 0
	write_liferay liferay-2 1

	write "    search:"
	write "        build: ./build/search"

	write_deploy 2G

	write "        environment:"
	write "            - discovery.type=single-node"
	write "            - xpack.ml.enabled=false"
	write "            - xpack.monitoring.enabled=false"
	write "            - xpack.security.enabled=false"
	write "            - xpack.sql.enabled=false"
	write "            - xpack.watcher.enabled=false"
	write "volumes:"
	write "     liferay-document-library:"
	write "     mysql-db:"

	write "    webserver:"
	write "        build: ./build/webserver"

	write_deploy 1G

	write "        ports:"
	write "            - 127.0.0.1:80:80"
}

function lcd {
	cd "${1}" || exit 3
}

function main {
	check_usage "${@}"

	generate_configuration | tee -a "${STACK_DIR}/build.out"

	print_image_usage | tee -a "${STACK_DIR}/build.out"
}

function print_image_usage {
	local docker_compose="docker compose"

	if (command -v docker-compose &>/dev/null)
	then
		docker_compose="docker-compose"
	fi

	echo ""
	echo "The configuration is ready to use. It's available in the ${STACK_NAME} folder. To start all services up, use the following commands:"
	echo ""
	echo "cd ${STACK_NAME}"
	echo "${docker_compose} up -d antivirus database search && ${docker_compose} up liferay-1"
	echo ""
	echo "If you would like to test with clustering, start the second liferay node too: ${docker_compose} up liferay-2"
	echo ""
	echo "For more information visit https://liferay.atlassian.net/l/cp/eUNW1Dsx"
}

main "${@}"