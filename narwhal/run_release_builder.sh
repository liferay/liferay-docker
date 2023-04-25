#!/bin/bash

CACHE_DIR="${HOME}/.release-builder-cache"

if [ ! -d "${CACHE_DIR}" ]
then
	echo "Creating the builder cache folder in ${CACHE_DIR}."

	sudo install -d "${CACHE_DIR}" -m 0775 -o 1000
fi

cd templates/release-builder || exit 3

if [ -e "${HOME}/.1password/agent.sock" ]
then
	SSH_CONFIG="-e SSH_AUTH_SOCK=/ssh-agent -v ${HOME}/.1password/agent.sock:/ssh-agent"
elif [ ! -s "${SSH_AUTH_SOCK}" ]
then
	SSH_CONFIG="-e SSH_AUTH_SOCK=/ssh-agent -v ${SSH_AUTH_SOCK}:/ssh-agent"
else
	if [ -f "$HOME/.ssh/id_ed25519" ]
	then
		SSH_PUBKEY_FILE="$HOME/.ssh/id_ed25519"
    elif [ -f "$HOME/.ssh/id_rsa" ];
	then
		SSH_PUBKEY_FILE="$HOME/.ssh/id_rsa"
	else
		echo "No \${SSH_AUTH_SOCK} or public key present. Exiting."

		exit 1
	fi
	SSH_CONFIG="-e NARWHAL_GITHUB_SSH_KEY=\"$(cat "${HOME}"/"${SSH_PUBKEY_FILE}")\""
fi

# shellcheck disable=SC2086,SC2068
docker run -it -v "${CACHE_DIR}:/opt/liferay/" ${SSH_CONFIG} ${@} $(docker -l warning build . --quiet -t release-builder)