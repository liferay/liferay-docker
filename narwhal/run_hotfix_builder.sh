#!/bin/bash

if [ ! -e ${HOME}/.hotfix-builder-cache ]
then
	echo "Creating the builder cache folder in ${HOME}/.hotfix-builder-cache. sudo will ask for your password to chown."
	mkdir -p ${HOME}/.hotfix-builder-cache
	sudo chown 1000 ${HOME}/.hotfix-builder-cache
fi

cd templates/hotfix-builder

docker build . -t hotfix-builder && docker run -it -v ${HOME}/.hotfix-builder-cache:/opt/liferay/ -e NARWHAL_BUILD_ID=1 -e NARWHAL_GIT_SHA=fix-pack-fix-240397335 -e NARWHAL_GITHUB_SSH_KEY="$(cat $HOME/.ssh/id_rsa)" hotfix-builder
