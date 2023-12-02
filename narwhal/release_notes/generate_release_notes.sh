#!/bin/bash

source _liferay_common.sh

function find_git_dir {
	lc_cd /home/me/dev/projects/liferay-portal-ee
}

function generate_release_notes {
	local version="${1}"

	local ga_version

	if (echo "${version}" | grep -q "q")
	then
		ga_version=7.4.13-ga1
	elif (echo "${version}" | grep -q "7.4")
	then
		ga_version=${version%%-u*}-ga1
	else
		ga_version=fix-pack-base-$(echo "${version%%-u*}" | sed -e s/[.]//g)
	fi

	local fixed_issues=$(git log "${ga_version}..${version}" --pretty=%s | grep -E "^[A-Z][A-Z0-9]*-[0-9]*" | sed -e "s/^\([A-Z][A-Z0-9]*-[0-9]*\).*/\\1/" | sort | uniq | grep -v POSHI | grep -v RELEASE | grep -v LRQA | grep -v LRCI | paste -sd,)

	echo "UPDATE OSB_PatcherProjectVersion SET fixed_issues='${fixed_issues}' WHERE committish='${version}';" >> "${OUTPUT_FILE}"
}

function main {
	OUTPUT_FILE=$(pwd)/release_notes_update.sql

	rm -f "${OUTPUT_FILE}"

	lc_time_run find_git_dir

	lc_time_run update_git

	lc_time_run generate_release_notes 2023.q3.1

	lc_time_run generate_release_notes 7.3.10-u35
}

function update_git {
	git fetch upstream --force --tags
}

main "${@}"