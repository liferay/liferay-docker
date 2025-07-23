#!/bin/bash

while true
do
	git pull origin master

	if [ $(date +%w) == 0 ]
	then
		docker system prune --all --force

		git clean -dfx

		LIFERAY_DOCKER_DEVELOPER_MODE=true LIFERAY_DOCKER_IMAGE_FILTER=7.4.13.nightly ./build_all_images.sh --push-all
	else
		LIFERAY_DOCKER_IMAGE_FILTER=7.4.13.nightly ./build_all_images.sh --push-all
	fi

	echo ""
	echo `date`
	echo ""

	sleep 1d
done