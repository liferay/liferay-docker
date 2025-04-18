#!/bin/bash

source /usr/local/bin/_liferay_bundle_common.sh

function main {
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
	else
		echo "[LIFERAY] The directory /mnt/liferay/deploy does not exist. Create the directory \$(pwd)/xyz123/deploy on the host operating system to create the directory ${LIFERAY_MOUNT_DIR}/deploy on the container. Copy files to \$(pwd)/xyz123/deploy to deploy modules to ${LIFERAY_PRODUCT_NAME} at runtime."
	fi

	if [ -z "${LIFERAY_OPENSEARCH_ENABLED}" ]
	then
		LIFERAY_OPENSEARCH_ENABLED="false"

		echo "[LIFERAY] Set the environment variable \"LIFERAY_OPENSEARCH_ENABLED\" to \"true\" to enable OpenSearch 2."
	fi

	if [ "${LIFERAY_OPENSEARCH_ENABLED}" == "true" ]
	then
		rm -f "/opt/liferay/osgi/configs/com.liferay.portal.search.elasticsearch7.configuration.ElasticsearchConfiguration.config"
	else
		rm -f "/opt/liferay/deploy/com.liferay.portal.search.opensearch2.api.jar"
		rm -f "/opt/liferay/deploy/com.liferay.portal.search.opensearch2.impl.jar"
		rm -f "/opt/liferay/osgi/configs/com.liferay.portal.search.opensearch2.configuration.OpenSearchConfiguration.config"
		rm -f "/opt/liferay/osgi/configs/com.liferay.portal.search.opensearch2.configuration.OpenSearchConnectionConfiguration-REMOTE.config"

		local blacklist_config_path="/opt/liferay/osgi/configs/com.liferay.portal.bundle.blacklist.internal.configuration.BundleBlacklistConfiguration.config"

		sed -i "s/com.liferay.portal.search.elasticsearch.cross.cluster.replication.impl//g" "${blacklist_config_path}"
		sed -i "s/com.liferay.portal.search.elasticsearch.monitoring.web//g" "${blacklist_config_path}"
		sed -i "s/com.liferay.portal.search.elasticsearch7.api//g" "${blacklist_config_path}"
		sed -i "s/com.liferay.portal.search.elasticsearch7.impl//g" "${blacklist_config_path}"
		sed -i "s/com.liferay.portal.search.learning.to.rank.api//g" "${blacklist_config_path}"
		sed -i "s/com.liferay.portal.search.learning.to.rank.impl//g" "${blacklist_config_path}"

		sed -i "s/\"\",\\\\//g" "${blacklist_config_path}"
		sed -i "s/\"\"\\\\//g" "${blacklist_config_path}"

		if (! grep -q "\"" "${blacklist_config_path}")
		then
			echo "[LIFERAY] Deleting com.liferay.portal.bundle.blacklist.internal.configuration.BundleBlacklistConfiguration.config."

			rm -f "${blacklist_config_path}"
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

main