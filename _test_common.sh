#!/bin/bash

source _liferay_common.sh

function assert_equals {
	local arguments=()

	for argument in "${@}"
	do
		arguments+=("${argument}")
	done

	local assertion_error_file="${PWD}/assertion_error"
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
			else
				assertion_result="false"

				break
			fi
		else
			if [ "${arguments[${index}]}" == "${arguments[${index} + 1]}" ]
			then
				assertion_result="true"
			else
				assertion_result="false"

				touch "${assertion_error_file}"

				echo -e "Actual: ${arguments[${index}]}\n" >> "${assertion_error_file}"
				echo -e "Expected: ${arguments[${index} + 1]}\n" >> "${assertion_error_file}"
			fi
		fi
	done

	if [ "${assertion_result}" == "true" ]
	then
		echo -e "${FUNCNAME[1]} \e[1;32mSUCCESS\e[0m\n"
	else
		echo -e "${FUNCNAME[1]} \e[1;31mFAILED\e[0m\n"

		cat "${assertion_error_file}"

		rm -f "${assertion_error_file}"
	fi
}

function main {
	if [ -n "${BASH_SOURCE[3]}" ]
	then
		echo -e "\n##### Running tests of $(echo ${BASH_SOURCE[3]} | sed -r 's/\.\///g') #####\n"
	elif [ -n "${BASH_SOURCE[2]}" ]
	then
		echo -e "\n##### Running tests of $(echo ${BASH_SOURCE[2]} | sed -r 's/\.\///g') #####\n"
	fi
}

main