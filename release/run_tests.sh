#!/bin/bash

function main {
	tests_result=$(find . -name "test_*.sh" -type f -exec ./{} \;)

	echo "${tests_result}"
	
	if [[ "${tests_result}" == *"FAILED"* ]]
	then
		exit 1
	fi
}

main