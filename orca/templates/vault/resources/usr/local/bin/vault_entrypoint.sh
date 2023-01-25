#!/bin/bash

if [ "${ORCA_DEVELOPMENT_MODE}" == "true" ]
then
	init_secrets.sh &
fi

vault server -config=/opt/liferay/vault/config.hcl