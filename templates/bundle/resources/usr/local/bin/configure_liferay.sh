#!/bin/bash

source /usr/local/bin/_liferay_bundle_common.sh
source /usr/local/bin/_liferay_common.sh

function main {
	if [ "${JAVA_VERSION}" == "zulu21" ] && [ ! -f "/opt/liferay/.elasticsearch7-startup" ]
	then
		rm --force --recursive /opt/liferay/data/elasticsearch7

		touch /opt/liferay/.elasticsearch7-startup
	fi

	if [ "${LIFERAY_DISABLE_TRIAL_LICENSE}" == "true" ]
	then
		rm -f /opt/liferay/data/license/trial-commerce-enterprise-license-*.li
		rm -f /opt/liferay/deploy/trial-dxp-license-*.xml
	fi

	if [ -n "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE}" ]
	then
		LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD=$(cat "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE}")

		export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD

		unset LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE
	fi

	if [ -n "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME_FILE}" ]
	then
		LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=$(cat "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME_FILE}")

		export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME

		unset LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME_FILE
	fi

	if [ ! -d "${LIFERAY_MOUNT_DIR}" ]
	then
		echo "[LIFERAY] Run this container with the option \"-v \$(pwd)/xyz123:/mnt/liferay\" to bridge \$(pwd)/xyz123 in the host operating system to ${LIFERAY_MOUNT_DIR} on the container."
		echo ""
	fi

	if [ -d "${LIFERAY_MOUNT_DIR}"/files ]
	then
		if [[ $(ls -A "${LIFERAY_MOUNT_DIR}"/files) ]]
		then
			echo "[LIFERAY] Copying files from ${LIFERAY_MOUNT_DIR}/files:"
			echo ""

			tree --noreport "${LIFERAY_MOUNT_DIR}"/files

			echo ""
			echo "[LIFERAY] ... into ${LIFERAY_HOME}."

			cp -r "${LIFERAY_MOUNT_DIR}"/files/* "${LIFERAY_HOME}"

			echo ""
		fi
	else
		echo "[LIFERAY] The directory /mnt/liferay/files does not exist. Create the directory \$(pwd)/xyz123/files on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/files on the container. Files in ${LIFERAY_MOUNT_DIR}/files will be copied to ${LIFERAY_HOME} before ${LIFERAY_PRODUCT_NAME} starts."
		echo ""
	fi

	if [ -d "${LIFERAY_MOUNT_DIR}"/scripts ]
	then
		execute_scripts "${LIFERAY_MOUNT_DIR}"/scripts
	else
		echo "[LIFERAY] The directory /mnt/liferay/scripts does not exist. Create the directory \$(pwd)/xyz123/scripts on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/scripts on the container. Files in ${LIFERAY_MOUNT_DIR}/scripts will be executed, in alphabetical order, before ${LIFERAY_PRODUCT_NAME} starts."
		echo ""
	fi

	if [ -d "${LIFERAY_MOUNT_DIR}"/deploy ]
	then
		if [[ $(ls -A /opt/liferay/deploy) ]]
		then
			cp /opt/liferay/deploy/* "${LIFERAY_MOUNT_DIR}"/deploy
		fi

		rm -fr /opt/liferay/deploy

		ln -s "${LIFERAY_MOUNT_DIR}"/deploy /opt/liferay/deploy

		echo "[LIFERAY] The directory /mnt/liferay/deploy is ready. Copy files to \$(pwd)/xyz123/deploy on the host operating system to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
		echo ""
	else
		echo "[LIFERAY] The directory /mnt/liferay/deploy does not exist. Create the directory \$(pwd)/xyz123/deploy on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/deploy on the container. Copy files to \$(pwd)/xyz123/deploy to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
		echo ""
	fi

	if [ "${LIFERAY_SLIM}" == "true" ]
	then
		slim

		if [ "${?}" -eq "${LIFERAY_COMMON_EXIT_CODE_BAD}" ]
		then
			echo "[LIFERAY] Unable to slim container. Ensure that the necessary environment variables are set."
			echo ""

			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi

	export LIFERAY_PATCHING_DIR="${LIFERAY_MOUNT_DIR}"/patching

	if [ -e /opt/liferay/patching-tool ]
	then
		patch_liferay.sh
	fi

	if [ -n "${LIFERAY_TOMCAT_AJP_PORT}" ]
	then
		sed -i s/'<!-- Define an AJP 1.3 Connector on port 8009 -->'/"<Connector address=\"0.0.0.0\" port=\"${LIFERAY_TOMCAT_AJP_PORT}\" protocol=\"AJP\/1.3\" redirectPort=\"8443\" secretRequired=\"false\" URIEncoding=\"UTF-8\" \/>"/ /opt/liferay/tomcat/conf/server.xml
	fi

	if [ -n "${LIFERAY_TOMCAT_JVM_ROUTE}" ]
	then
		sed -i s/"<Engine name=\"Catalina\" defaultHost=\"localhost\">"/"<Engine defaultHost=\"localhost\" jvmRoute=\"${LIFERAY_TOMCAT_JVM_ROUTE}\" name=\"Catalina\">"/ /opt/liferay/tomcat/conf/server.xml
	fi
}

function slim {
	if (! echo "${LIFERAY_NETWORK_HOST_ADDRESSES}" | grep --quiet --perl-regexp "\[?(\"?(http|https):\/\/[.\w-]+:[\d]+\"?)+(,\s*\"(http|https):\/\/[.\w-]+:[\d]+\")*\]?")
	then
		echo "[LIFERAY] Run this container with the option \"--env LIFERAY_NETWORK_HOST_ADDRESSES=[\"http://node1:9201\", \"http://node2:9202\"]\" to connect to remote search servers (Elasticsearch or OpenSearch)."
		echo ""

		if [ "${LIFERAY_DOCKER_TEST_MODE}" != "true" ]
		then
			return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
		fi
	fi

	if [ -z "${LIFERAY_OPENSEARCH_ENABLED}" ]
	then
		LIFERAY_OPENSEARCH_ENABLED="false"

		echo "[LIFERAY] Run this container with the option \"--env LIFERAY_OPENSEARCH_ENABLED=true\" to enable OpenSearch."
		echo ""
	fi

	if [ "${LIFERAY_OPENSEARCH_ENABLED}" == "true" ]
	then
		if [ -z "${LIFERAY_OPENSEARCH_PASSWORD}" ]
		then
			echo "[LIFERAY] Run this container with the option \"--env LIFERAY_OPENSEARCH_PASSWORD=myfancypassword\" to set your OpenSearch password."
			echo ""

			if [ "${LIFERAY_DOCKER_TEST_MODE}" != "true" ]
			then
				return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
			fi
		fi

		if [ ! -f "/opt/liferay/osgi/configs/com.liferay.portal.bundle.blacklist.internal.configuration.BundleBlacklistConfiguration.config" ]
		then
			(
				echo "blacklistBundleSymbolicNames=[\\"
				echo "\"com.liferay.portal.search.elasticsearch.cross.cluster.replication.impl\",\\"
				echo "\"com.liferay.portal.search.elasticsearch.monitoring.web\",\\"
				echo "\"com.liferay.portal.search.elasticsearch7.api\",\\"
				echo "\"com.liferay.portal.search.elasticsearch7.impl\",\\"
				echo "\"com.liferay.portal.search.learning.to.rank.api\",\\"
				echo "\"com.liferay.portal.search.learning.to.rank.impl\"\\"
				echo "]"
			) > "/opt/liferay/osgi/configs/com.liferay.portal.bundle.blacklist.internal.configuration.BundleBlacklistConfiguration.config"
		fi

		if [ ! -f "/opt/liferay/osgi/configs/com.liferay.portal.search.opensearch2.configuration.OpenSearchConfiguration.config" ]
		then
			echo "remoteClusterConnectionId=\"REMOTE\"" > "/opt/liferay/osgi/configs/com.liferay.portal.search.opensearch2.configuration.OpenSearchConfiguration.config"
		fi

		if [ ! -f "/opt/liferay/osgi/configs/com.liferay.portal.search.opensearch2.configuration.OpenSearchConnectionConfiguration-REMOTE.config" ]
		then
			(
				echo "active=B\"true\""
				echo "connectionId=\"REMOTE\""
				echo "networkHostAddresses=\"${LIFERAY_NETWORK_HOST_ADDRESSES}\""
				echo "password=\"${LIFERAY_OPENSEARCH_PASSWORD}\""
			) > "/opt/liferay/osgi/configs/com.liferay.portal.search.opensearch2.configuration.OpenSearchConnectionConfiguration-REMOTE.config"
		fi
	else
		if [ ! -f "/opt/liferay/osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config" ]
		then
			(
				echo "networkHostAddresses=\"${LIFERAY_NETWORK_HOST_ADDRESSES}\""
				echo "productionModeEnabled=B\"true\""
			) > "/opt/liferay/osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config"
		fi

		rm -f "/opt/liferay/deploy/com.liferay.portal.search.opensearch2.api.jar"
		rm -f "/opt/liferay/deploy/com.liferay.portal.search.opensearch2.impl.jar"
	fi
}

main