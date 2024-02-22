#!/bin/bash

while true
do
	LIFERAY_DOCKER_IMAGE_FILTER=7.4.13.nightly ./build_all_images.sh --push

	if [ $(date +%w) == 0 ]
	then
		docker system prune --all --force
	fi

	echo ""
	echo `date`
	echo ""

	sleep 1d
done