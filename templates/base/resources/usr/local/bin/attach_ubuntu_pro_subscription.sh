#!/bin/bash

if [ -n "${1}" ]
then
	LIFERAY_DOCKER_UBUNTU_PRO_TOKEN="${1}"
fi

if [ -z "${LIFERAY_DOCKER_UBUNTU_PRO_TOKEN}" ]
then
	echo "Ubuntu Pro subscription attachment is skipped as LIFERAY_DOCKER_UBUNTU_PRO_TOKEN is not set."

	exit 1
fi

if (pro status 2>/dev/null | grep -q "Subscription: Ubuntu Pro" 2>/dev/null)
then
	echo "Ubuntu Pro subscription is already active."

	exit 0
fi

apt-get update && \
DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes ubuntu-advantage-tools && \
pro attach "${LIFERAY_DOCKER_UBUNTU_PRO_TOKEN}"