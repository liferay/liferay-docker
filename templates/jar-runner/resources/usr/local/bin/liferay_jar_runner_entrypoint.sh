#!/bin/bash

function main {
	export JAVA_HOME="/usr/lib/jvm/${JAVA_VERSION}"
	export PATH="/usr/lib/jvm/${JAVA_VERSION}/bin/:${PATH}"

	if [ -e /usr/local/bin/liferay_jar_runner_set_up.sh ]
	then
		/usr/local/bin/liferay_jar_runner_set_up.sh
	fi

	java ${LIFERAY_JAR_RUNNER_JAVA_OPTS} -jar /opt/liferay/jar-runner.jar "${@}" &

	trap "kill ${!}" INT TERM

	#
	# The first wait returns as soon as the trap runs, while the application is
	# still shutting down. The second wait blocks until it actually exits.
	#

	wait "${!}"

	wait "${!}"

	if [ -e /usr/local/bin/liferay_jar_runner_tear_down.sh ]
	then
		/usr/local/bin/liferay_jar_runner_tear_down.sh
	fi
}

main "${@}"