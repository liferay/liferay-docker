#!/bin/bash

function main {
	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	if [ "${LIFERAY_JPDA_ENABLED}" == "true" ]
	then
		exec "${LIFERAY_HOME}"/tomcat/bin/catalina.sh jpda run
	else
		exec "${LIFERAY_HOME}"/tomcat/bin/catalina.sh run
	fi
}

main