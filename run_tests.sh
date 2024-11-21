#!/bin/bash

function main {
	local tests_results=$(\
		find . \( -name "test_build_*.sh" -o -name "test_patching_tool_version.sh" \) -type f -exec ./{} \; && \
		\
		cd release && \
		\
		find . -name "test_*.sh" -type f -exec ./{} \;)

	echo "${tests_results}"

	if [[ "${tests_results}" == *"FAILED"* ]]
	then
		exit 1
	fi
}

main