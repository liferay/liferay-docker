#!/bin/bash

function main {
	if [ -z "${DISPLAY_SUCCESSFUL_TEST_RESULT}" ]
	then
		export DISPLAY_SUCCESSFUL_TEST_RESULT="false"
	fi

	local test_results=""

	local changed_files=$(git diff --name-only upstream/master)

	if [ -z "${changed_files}" ]
	then
		test_results=$((_run_docker_tests && _run_release_tests) 2>&1 | tee /dev/stderr)
	else
		test_results=$(_run_docker_tests "${changed_files}" 2>&1 | tee /dev/stderr)

		if [ -n "${test_results}" ]
		then
			test_results+=$'\n'
		fi

		test_results+=$(_run_release_tests "${changed_files}" 2>&1 | tee /dev/stderr)
	fi

	if [[ "${test_results}" == *"FAILED"* ]]
	then
		exit 1
	fi

	unset DISPLAY_SUCCESSFUL_TEST_RESULT
}

function _run_docker_tests {
	if [ -z "${1}" ]
	then
		find . \
			-maxdepth 1 \
			-name "test_*.sh" ! -name "test_bundle_image.sh" \
			-type f \
			| sort \
			| xargs --max-args=1 /bin/bash
	else
		for changed_file in $(echo "${1}" | grep --extended-regexp "^[^/]+\.sh$")
		do
			find . \
				-name "test_$(basename ${changed_file} | sed "s/^_//")" \
				-type f \
				| xargs --max-args=1 /bin/bash
		done
	fi
}

function _run_release_tests {
	cd release

	if [ -z "${1}" ]
	then
		find . \
			-name "test_*.sh" \
			-type f \
			| sort \
			| xargs --max-args=1 /bin/bash
	else
		for changed_file in $(echo "${1}" | grep --extended-regexp "^release/.*\.sh$|^release/test-dependencies/.*")
		do
			find . \
				-name "test_$(basename ${changed_file} | sed "s/^_//")" ! -name "test_build_release.sh" \
				-type f \
				| xargs --max-args=1 /bin/bash
		done

		/bin/bash test_build_release.sh
	fi
}

main