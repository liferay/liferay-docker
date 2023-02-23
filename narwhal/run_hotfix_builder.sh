#!/bin/bash


CACHE_DIR="${HOME}/.hotfix-builder-cache"
NARWHAL_GIT_SHA="fix-pack-fix-240397335"

if [ ! -d "${CACHE_DIR}" ]
then
	echo "Creating the builder cache folder in ${CACHE_DIR}."
	sudo install -d "${CACHE_DIR}" -m 0775 -o 1000
fi

cd templates/hotfix-builder || exit 1

if [ ! -s "$SSH_AUTH_SOCK" ]
then
	docker -l warning build . --quiet -t hotfix-builder && docker run -it -v "${CACHE_DIR}:/opt/liferay/" -v "${SSH_AUTH_SOCK}:/ssh-agent" -e NARWHAL_BUILD_ID=1 -e NARWHAL_GIT_SHA="${NARWHAL_GIT_SHA}" -e SSH_AUTH_SOCK="/ssh-agent" hotfix-builder
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
	docker -l warning build --quiet . -t hotfix-builder && docker run -it -e NARWHAL_BUILD_ID=1 -e NARWHAL_GIT_SHA="${NARWHAL_GIT_SHA}" -e NARWHAL_GITHUB_SSH_KEY="$(cat "${HOME}/${SSH_PUBKEY_FILE}")" -v "${CACHE_DIR}:/opt/liferay/" hotfix-builder
fi