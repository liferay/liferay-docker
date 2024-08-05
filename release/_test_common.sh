#!/bin/bash

function assert_equals {
	local arguments=()

	for argument in ${@}
	do
		arguments+=(${argument})
	done

	local assertion_result="false"

	for index in ${!arguments[@]}
	do
		if [ $((index % 2)) -ne 0 ]
		then
			continue
		fi

		if [ -f "${arguments[${index}]}" ] &&
		   [ -f "${arguments[${index} + 1]}" ]
		then
			diff "${arguments[${index}]}" "${arguments[${index} + 1]}"

			if [ "${?}" -eq 0 ]
			then
				assertion_result="true"
			fi
		else
			if [ "${arguments[${index}]}" == "${arguments[${index} + 1]}" ]
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