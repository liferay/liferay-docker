#!/bin/bash

function main {
	export JAVA_HOME=/usr/lib/jvm/${JAVA_VERSION}
	export PATH=/usr/lib/jvm/${JAVA_VERSION}/bin/:${PATH}

	if [ -e /opt/liferay/caroot/rootCA.pem ]
	then
		export CAROOT=/opt/liferay/caroot
		export TRUST_STORES=java,system

		mkcert -install
	fi

	if [ -e /usr/local/bin/liferay_jar_runner_set_up.sh ]
	then
		/usr/local/bin/liferay_jar_runner_set_up.sh
	fi

	java ${LIFERAY_JAR_RUNNER_JAVA_OPTS} -jar /opt/liferay/jar-runner.jar

	if [ -e /usr/local/bin/liferay_jar_runner_tear_down.sh ]
	then
		/usr/local/bin/liferay_jar_runner_tear_down.sh
	fi
}

main