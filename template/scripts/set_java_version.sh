#!/bin/bash

function main {
	if [ -n "$LIFERAY_JAVA_VERSION" ]
	then
		if [ -e "/usr/lib/jvm/${LIFERAY_JAVA_VERSION}" ]
		then
			JAVA_HOME=/usr/lib/jvm/${LIFERAY_JAVA_VERSION}
			PATH=/usr/lib/jvm/${LIFERAY_JAVA_VERSION}/bin/:${PATH}

			echo "[LIFERAY] Making ${LIFERAY_JAVA_VERSION} the default."
			echo ""
		else
			echo "[LIFERAY] Java version \"${LIFERAY_JAVA_VERSION}\" is not available in this Docker image."
			echo ""

			exit 1
		fi
	fi
}

main