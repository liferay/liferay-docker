#!/bin/bash

function main {
	echo ""
	echo "[LIFERAY] Starting ${LIFERAY_PRODUCT_NAME}. To stop the container with CTRL-C, run this container with the option \"-it\"."
	echo ""

	if [ -n "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME_FILE}" ]
	then
	  LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME=$(cat $LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME_FILE)
	  export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_USERNAME
  fi

	if [ -n "${LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE}" ]
	then
	  LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD=$(cat $LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD_FILE)
	  export LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_PASSWORD
  fi

	if [ "${LIFERAY_JPDA_ENABLED}" == "true" ]
	then
		${LIFERAY_HOME}/tomcat/bin/catalina.sh jpda run
	else
		${LIFERAY_HOME}/tomcat/bin/catalina.sh run
	fi
}

main