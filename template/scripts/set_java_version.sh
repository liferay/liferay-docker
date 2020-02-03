#!/bin/bash

function main {
	if [ -n "$JAVA_VERSION" ]
	then
		if [ -e "/usr/lib/jvm/${JAVA_VERSION}" ]
		then
			JAVA_HOME=/usr/lib/jvm/${JAVA_VERSION}
			PATH=/usr/lib/jvm/${JAVA_VERSION}/bin/:${PATH}

			echo "[LIFERAY] Setting ${JAVA_VERSION} JDK the default one. You can choose another JDK version by setting the JAVA_VERSION varible."
			echo ""
		else
			echo "[LIFERAY] Java version \"${JAVA_VERSION}\" is not available in this Docker image."
			echo ""

			exit 1
		fi
	fi
}

main