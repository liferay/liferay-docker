#!/bin/bash

if [ "${ORCA_DEVELOPMENT_MODE}" == "true" ]
then
	if [ ! -e /opt/liferay/vault/data/vault.db ]
	then
		init_secrets.sh &
	else
		auto_unseal.sh &
	fi
fi

vault server -config=/opt/liferay/vault/config.hcl