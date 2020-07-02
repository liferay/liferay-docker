#!/bin/bash

source ./_common.sh

function check_usage {
	check_utils git sed sort tr
}

function generate_release_notes {
	CURRENT_SHA=$(git log -1 --pretty=%H)
	CHANGELOG=$(git log --pretty=%s --grep "^LPS-" ${LATEST_SHA}..${CURRENT_SHA} | sed -e "s/\ .*/ /" | uniq | tr -d "\n" | tr -d "\r" | sed -e "s/ $//")

	if [ -n "${CHANGELOG}" ]
	then
		VERSION_MICRO=$(($VERSION_MICRO+1))

		(
			echo ""
			echo "#"
			echo "# Liferay Docker Image Version ${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO}"
			echo "#"
			echo ""
			echo "docker.image.change.log-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO}=${CHANGELOG}"
			echo "docker.image.git.id-${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO}=${CURRENT_SHA}"
		) >> .releng/docker-image.changelog
	fi
}

function get_latest_version {
	local git_line=$(cat .releng/docker-image.changelog | grep docker.image.git.id | tail -n1)

	LATEST_SHA=${git_line#*=}
	LATEST_VERSION=${git_line#*-}
	LATEST_VERSION=${LATEST_VERSION%=*}

	VERSION_MAJOR=${LATEST_VERSION%%.*}
	VERSION_MINOR=${LATEST_VERSION#*.}
	VERSION_MINOR=${VERSION_MINOR%.*}
	VERSION_MICRO=${LATEST_VERSION##*.}
}

function main {
	check_usage ${@}

	get_latest_version

	generate_release_notes
}

main ${@}