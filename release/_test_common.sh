#!/bin/bash

function assert_equals {
	if [ "${1}" = 1 ] || [ "${1}" = true ]
	then
		echo "${FUNCNAME[1]} SUCCESS"
	else
		echo "${FUNCNAME[1]} FAILED"

		if [ -n "${2}" ]
		then
			echo "${2}"
		fi
	fi
}