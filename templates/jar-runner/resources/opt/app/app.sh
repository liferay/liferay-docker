#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/zulu11

if [ -e /etc/liferay/localdev/rootCA.pem ]; then
	export CAROOT=/var/lib/caroot
	export TRUST_STORES=java,system
	cp -f /etc/liferay/localdev/rootCA.pem $CAROOT
	mkcert -install
fi

java ${LIFERAY_JAR_RUNNER_OPTS} -jar /opt/app/app.jar