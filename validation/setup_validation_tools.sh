#!/bin/bash

function install_lefthook {
	apt-get update
	apt-get -y install npm
	npm install @arkweid/lefthook --save-dev
}

function main {
	install_lefthook
}

main