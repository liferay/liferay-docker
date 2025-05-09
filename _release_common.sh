#!/bin/bash

function get_latest_quartely_version {
	local version_1=$(echo "${1}" | sed -e "s/-lts//")
	local version_2=$(echo "${2}" | sed -e "s/-lts//")

	IFS='.' read -r version_1_year version_1_quarter version_1_sufix <<< "${version_1}"
	IFS='.' read -r version_2_year version_2_quarter version_2_sufix <<< "${version_2}"

	version_1_quarter=$(echo "${version_1_quarter}" | sed -e "s/q//")
	version_2_quarter=$(echo "${version_2_quarter}" | sed -e "s/q//")

	if [ "${version_1_year}" -gt "${version_2_year}" ]
	then
		echo "${1}"

		return
	elif [ "${version_1_year}" -lt "${version_2_year}" ]
	then
		echo "${2}"

		return
	fi

	if [ "${version_1_quarter}" -gt "${version_2_quarter}" ]
	then
		echo "${1}"

		return
	elif [ "${version_1_quarter}" -lt "${version_2_quarter}" ]
	then
		echo "${2}"

		return
	fi

	if [ "${version_1_sufix}" -gt "${version_2_sufix}" ]
	then
		echo "${1}"

		return
	elif [ "${version_1_sufix}" -lt "${version_2_sufix}" ]
	then
		echo "${2}"

		return
	fi

	echo "${1}"
}