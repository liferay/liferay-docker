#!/bin/bash

function assert_equals {
	local parameters=()

	for parameter in ${@}; do
		parameters+=(${parameter})
	done

	local assertion_result="false"

	for index in ${!parameters[@]}; do
		if [ $((index % 2)) -ne 0 ]
		then
			continue
		fi

		if [ -f "${parameters[${index}]}" ] &&
		   [ -f "${parameters[${index} + 1]}" ]
		then
			diff "${parameters[${index}]}" "${parameters[${index} + 1]}"

			if [ "${?}" -eq 0 ]
			then
				assertion_result="true"
			fi
		else
			if [ "${parameters[${index}]}" == "${parameters[${index} + 1]}" ]
			then
				assertion_result="true"
			fi
		fi
	done

	if [ "${assertion_result}" == "true" ]
	then
		echo -e "${FUNCNAME[1]} \e[1;32mSUCCESS\e[0m"
	else
		echo -e "${FUNCNAME[1]} \e[1;31mFAILED\e[0m"
	fi
}