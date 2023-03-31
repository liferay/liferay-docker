#!/bin/sh

if [ -e /opt/node/caroot/rootCA.pem ]
then
	export NODE_EXTRA_CA_CERTS=/opt/node/caroot/rootCA.pem
fi

$LIFERAY_NODE_RUNNER_START
