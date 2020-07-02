#!/bin/bash

source ./_common.sh

function check_usage {
	if [ ! -n "${1}" ]
	then
		echo "Usage: ${0} <command>"
		echo ""
		echo "This script requires the first parameter to be set to one of these options:"
		echo ""
		echo "    commit: Writes and commits the necessary version change with the changelog"
		echo "    fail-on-change: The script will return an error code if there was a version number changing commit since the last release notes change"
		echo "    get-version: Returns the current version number"
		echo "    anything else: Display the required version number change"

		exit 1
	fi

	check_utils git sed sort tr
}

function generate_release_notes {
	if [ -n "${CHANGELOG}" ]
	then
		if ( git log --pretty=%s ${LATEST_SHA}..${CURRENT_SHA} | grep "#majorchange" > /dev/null )
		then
			VERSION_MAJOR=$(($VERSION_MAJOR+1))
			VERSION_MINOR=0
			VERSION_MICRO=0
		elif ( git log --pretty=%s ${LATEST_SHA}..${CURRENT_SHA} | grep "#minorchange" > /dev/null )
		then
			VERSION_MINOR=$(($VERSION_MINOR+1))
			VERSION_MICRO=0
		else
			VERSION_MICRO=$(($VERSION_MICRO+1))
		fi

		NEW_VERSION=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO}

		echo "Version bump from ${LATEST_VERSION} to ${NEW_VERSION}"

		if [ "${1}" == "commit" ]
		then
			(
				echo ""
				echo "#"
				echo "# Liferay Docker Image Version ${NEW_VERSION}"
				echo "#"
				echo ""
				echo "docker.image.change.log-${NEW_VERSION}=${CHANGELOG}"
				echo "docker.image.git.id-${NEW_VERSION}=${CURRENT_SHA}"
			) >> .releng/docker-image.changelog

			git add .releng/docker-image.changelog
			git commit -m "${NEW_VERSION} changelog"
		fi
	fi
}

function get_changelog {
	CURRENT_SHA=$(git log -1 --pretty=%H)
	CHANGELOG=$(git log --pretty=%s --grep "^LPS-" ${LATEST_SHA}..${CURRENT_SHA} | sed -e "s/\ .*/ /" | uniq | tr -d "\n" | tr -d "\r" | sed -e "s/ $//")

	if [ "${1}" == "fail-on-change" ] && [ -n "${CHANGELOG}" ]
	then
		echo "There was a change in the repository which requires regenerating the release notes."
		echo "Run \"./release_notes.sh commit\" to commit the updated changelog."

		exit 1
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

	if [ "${1}" == "get-version" ]
	then
		echo ${LATEST_VERSION}

		exit
	fi
}

function main {
	check_usage ${@}

	get_latest_version ${@}

	get_changelog ${@}

	generate_release_notes ${@}
}

main ${@}