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
		if (echo "${changed_files}" | grep --extended-regexp "^[^/]+\.sh$" --quiet)
		then
			test_results=$(_run_docker_tests 2>&1 | tee /dev/stderr)
		fi

		if (echo "${changed_files}" | grep --extended-regexp "^release/.*\.sh$|^release/test-dependencies/.*" --quiet)
		then
			if [ -n "${test_results}" ]
			then
				test_results+=$'\n'
			fi

			test_results+=$(_run_release_tests 2>&1 | tee /dev/stderr)
		fi
	fi

	if [[ "${test_results}" == *"FAILED"* ]]
	then
		exit 1
	fi

	unset DISPLAY_SUCCESSFUL_TEST_RESULT
}

function _run_docker_tests {
	find . -maxdepth 1 -name "test_*.sh" ! -name "test_bundle_image.sh" -type f -exec {} \;
}

function _run_release_tests {
	cd release

	find . -name "test_*.sh" -type f -exec {} \;
}

main