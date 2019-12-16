#!/bin/bash

function main {
	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	if [ "${LIFERAY_JPDA_ENABLED}" == "true" ]
	then
		export JPDA_ADDRESS=8000
		${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
	else
		${LIFERAY_HOME}/tomcat/bin/catalina.sh run
	fi
}

main