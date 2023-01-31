#!/bin/bash

function main {
	apt-get update
	apt-get --yes install docker-compose git glusterfs-server pwgen

	if (! command -v yq &> /dev/null)
	then
		snap install yq
	fi

	mkdir -p /opt/liferay/orca

	cd /opt/liferay/orca || exit 1

	git init
	git remote add origin https://github.com/liferay/liferay-docker.git
	git config core.sparseCheckout true

	echo "orca" >> .git/info/sparse-checkout

	git pull origin master

	#
	# TODO Fix /opt/liferay/orca/orca
	#

	cd orca || exit 1

	#
	# TODO install
	#

	scripts/orca.sh install
}

main