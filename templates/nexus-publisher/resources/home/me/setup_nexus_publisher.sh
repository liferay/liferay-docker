#!/bin/bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

function clone_repository {
	local repository_name=${1}

	git clone https://${LIFERAY_NEXUS_PUBLISHER_GIT_GITHUB_OATH_TOKEN}@github.com/brianchandotcom/${repository_name}.git

cat <<EOF > ${repository_name}/.git/config
[remote "origin"]
	fetch = +refs/heads/*:refs/remotes/origin/*
	url = https://${LIFERAY_NEXUS_PUBLISHER_GIT_GITHUB_OATH_TOKEN}@github.com/brianchandotcom/${repository_name}.git
[remote "upstream"]
	fetch = +refs/heads/*:refs/remotes/upstream/*
	url = https://${LIFERAY_NEXUS_PUBLISHER_GIT_GITHUB_OATH_TOKEN}@github.com/liferay/${repository_name}.git
EOF

	truncate --size -1 ${repository_name}/.git/config

cat <<EOF > ${repository_name}/build.me.properties
	build.repository.private.password=${LIFERAY_NEXUS_PUBLISHER_SONATYPE_PASSWORD}
	build.repository.private.username=${LIFERAY_NEXUS_PUBLISHER_SONATYPE_USERNAME}

	gradle.publish.key=${LIFERAY_NEXUS_PUBLISHER_GRADLE_PUBLISH_KEY}
	gradle.publish.secret=${LIFERAY_NEXUS_PUBLISHER_GRADLE_PUBLISH_SECRET}

	jsp.precompile=on

	nodejs.npm.access.token=${LIFERAY_NEXUS_PUBLISHER_NODEJS_NPM_ACCESS_TOKEN}

	release.versions.test.other.dir=${user.home}/dev/projects/liferay-portal-7.2.x

	sonatype.release.hostname=repository.liferay.com
	sonatype.release.password=${LIFERAY_NEXUS_PUBLISHER_SONATYPE_PASSWORD}
	sonatype.release.realm=Sonatype Nexus Repository Manager
	sonatype.release.url=https://repository.liferay.com/nexus/content/repositories/liferay-public-releases
	sonatype.release.username=${LIFERAY_NEXUS_PUBLISHER_SONATYPE_USERNAME}

	sonatype.snapshot.hostname=repository.liferay.com
	sonatype.snapshot.password=${LIFERAY_NEXUS_PUBLISHER_SONATYPE_PASSWORD}
	sonatype.snapshot.realm=Sonatype Nexus Repository Manager
	sonatype.snapshot.url=https://repository.liferay.com/nexus/content/repositories/liferay-public-snapshots
	sonatype.snapshot.username=${LIFERAY_NEXUS_PUBLISHER_SONATYPE_USERNAME}
EOF

	truncate --size -1 ${repository_name}/build.me.properties
}

function main {
	sed --in-place "s/GITHUB_OATH_TOKEN/${LIFERAY_NEXUS_PUBLISHER_GIT_GITHUB_OATH_TOKEN}/" .gitconfig
	sed --in-place "s/GITHUB_USER/${LIFERAY_NEXUS_PUBLISHER_GIT_GITHUB_USER}/" .gitconfig
	sed --in-place "s/USER_EMAIL/${LIFERAY_NEXUS_PUBLISHER_GIT_USER_EMAIL}/" .gitconfig
	sed --in-place "s/USER_NAME/${LIFERAY_NEXUS_PUBLISHER_GIT_USER_NAME}/" .gitconfig

	mkdir --parents dev/projects

	pushd dev/projects > /dev/null

	clone_repository liferay-portal
	clone_repository liferay-portal-ee

	popd > /dev/null
}

main "${@}"