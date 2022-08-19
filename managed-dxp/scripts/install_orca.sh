#!/bin/bash

function install_orca {
	mkdir -p /opt/liferay/orca

	cd /opt/liferay/orca

	git init
	git remote add origin https://github.com/liferay/liferay-docker.git
	git config core.sparseCheckout true

	echo "managed-dxp" >> .git/info/sparse-checkout

	git pull origin master

	cd managed-dxp

	./orca.sh install
}

function install_requirements {
	apt-get update
	apt-get --yes install docker-compose git glusterfs-server pwgen

	snap install yq
}

function main {
	install_requirements

	install_orca
}

main


