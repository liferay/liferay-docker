#!/bin/bash

function main {
	apt-get update
	apt-get --yes install docker-compose git glusterfs-server pwgen

	snap install yq

	mkdir -p /opt/liferay/orca

	cd /opt/liferay/orca

	git init
	git remote add origin https://github.com/liferay/liferay-docker.git
	git config core.sparseCheckout true

	echo "orca" >> .git/info/sparse-checkout

	git pull origin master

	cd orca

	scripts/orca.sh install
}

main


