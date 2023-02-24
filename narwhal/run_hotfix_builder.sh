#!/bin/bash

CACHE_DIR="${HOME}/.hotfix-builder-cache"
NARWHAL_GIT_SHA="fix-pack-fix-240397335"

if [ ! -d "${CACHE_DIR}" ]
then
	echo "Creating the builder cache folder in ${CACHE_DIR}."

	sudo install -d "${CACHE_DIR}" -m 0775 -o 1000
fi

cd templates/hotfix-builder

if [ ! -s "${SSH_AUTH_SOCK}" ]
then
	SSH_CONFIG="-e SSH_AUTH_SOCK="/ssh-agent" -v ${SSH_AUTH_SOCK}:/ssh-agent"
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
	SSH_CONFIG="-e NARWHAL_GITHUB_SSH_KEY=\"$(cat ${HOME}/${SSH_PUBKEY_FILE})\""
fi

docker -l warning build . --quiet -t hotfix-builder && \
	docker run -it -v "${CACHE_DIR}:/opt/liferay/" -e NARWHAL_BUILD_ID=1 -e NARWHAL_GIT_SHA="${NARWHAL_GIT_SHA}" ${SSH_CONFIG} hotfix-builder