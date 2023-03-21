#!/bin/bash

# USE THIS SCRIPT ON SINGLE SERVER CONFIGURATION FOR TESTING PURPOSES ONLY!


function gen_github(){
	# Configure GitHub authentication
	# GitHub credentials defined in configs/<env>-github.yml
	sed \
		-e "s/__GITHUB_ID__/$GITHUB_ID/" \
		-e "s/__GITHUB_REDIRECT_HOST__/$GITHUB_REDIRECT_HOST/" \
		-e "s/__GITHUB_SECRET__/$GITHUB_SECRET/" \
		/root/github.yaml.tpl > /root/github.yaml
	tctl create -f /root/github.yaml
}

function gen_token(){
	# Prepare a token for the agent so that it can join with it
	# $dir_export is a directory shared between teleport-proxy and teleport-agent-test docker containers

	dir_export="/agent-test"

	if [ ! -f ${dir_export}/token.txt ]
	then
		tctl tokens add --type=node | grep -oP '(?<=token:\s).*' > ${dir_export}/token.txt
	    chmod 600 ${dir_export}/*
	fi
}

function main(){
	gen_github

	gen_token
}

main