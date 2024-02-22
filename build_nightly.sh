#!/bin/bash

while true
do
	LIFERAY_DOCKER_IMAGE_FILTER=7.4.13.nightly ./build_all_images.sh --push

	docker system prune --all --force

	echo ""
	echo `date`
	echo ""

	sleep 1d
done