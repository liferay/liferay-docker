#!/bin/bash

function assert_equals {
	if [ "${1}" = 1 ] || [ "${1}" = true ]
	then
		echo -e "${FUNCNAME[1]} \e[1;32mSUCCESS\e[0m"
	else
		echo -e "${FUNCNAME[1]} \e[1;31mFAILED\e[0m"

		if [ -n "${2}" ]
		then
			echo "${2}"
		fi
	fi
}