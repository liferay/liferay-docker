#!/bin/bash

function main {
	local test_results=""

	local changed_files=$(git diff --name-only upstream/master)

	if [ -z "${changed_files}" ]
	then
		test_results=$((_run_docker_tests && _run_release_tests && _run_crowdin_tests) 2>&1 | tee /dev/stderr)
	else
		test_results=$(_run_docker_tests "${changed_files}" 2>&1 | tee /dev/stderr)

		if [ -n "${test_results}" ]
		then
			test_results+=$'\n'
		fi

		test_results+=$(_run_release_tests "${changed_files}" 2>&1 | tee /dev/stderr)

		if [ -n "${test_results}" ]
		then
			test_results+=$'\n'
		fi

		test_results+=$(_run_crowdin_tests "${changed_files}" 2>&1 | tee /dev/stderr)
	fi

	if [[ "${test_results}" == *"FAILED"* ]]
	then
		exit 1
	fi
}

function _get_test_files {
	local changed_file

	for changed_file in ${1}
	do
		local file_name=$(basename "${changed_file}")

		if [[ "${file_name}" == test_* ]]
		then
			echo "${file_name}"
		else
			echo "test_$(echo "${file_name}" | sed --expression "s/^_//")"
		fi
	done | sort --unique
}

function _run_crowdin_tests {
	(
		cd crowdin

		if [ -z "${1}" ]
		then
			find . -name "test_*.sh" -type f | \
				sort | \
				xargs --max-args=1 /bin/bash
		else
			local test_file

			for test_file in $(_get_test_files "$(echo "${1}" | grep --extended-regexp "^crowdin/.*\.sh$")")
			do
				find . -name "${test_file}" -type f | xargs --max-args=1 /bin/bash
			done
		fi
	)
}

function _run_docker_tests {
	if [ -z "${1}" ]
	then
		find . \
			-maxdepth 1 \
			-name "test_*.sh" ! -name "test_bundle_image.sh" \
			-type f | \
			sort | \
			xargs --max-args=1 /bin/bash
	else
		local test_file

		for test_file in $(_get_test_files "$(echo "${1}" | grep --extended-regexp "^[^/]+\.sh$")")
		do
			find . \
				-name "${test_file}" ! -name "test_bundle_image.sh" \
				-type f | xargs --max-args=1 /bin/bash
		done
	fi
}

function _run_release_tests {
	(
		cd release

		if [ -z "${1}" ]
		then
			find . -name "test_*.sh" -type f | \
				sort | \
				xargs --max-args=1 /bin/bash
		else
			local test_file

			for test_file in $(_get_test_files "$(echo "${1}" | grep --extended-regexp "^release/.*\.sh$")")
			do
				find . \
					-name "${test_file}" ! -name "test_build_release.sh" \
					-type f | xargs --max-args=1 /bin/bash
			done

			if echo "${1}" | grep --extended-regexp --quiet "^release/.*\.sh$"
			then
				/bin/bash test_build_release.sh
			fi
		fi
	)
}

main