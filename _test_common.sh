#!/bin/bash

function assert_equals {
	local arguments=()

	for argument in "${@}"
	do
		arguments+=("${argument}")
	done

	local assertion_error_file="${PWD}/assertion_error"

	for index in ${!arguments[@]}
	do
		if [ $((index % 2)) -ne 0 ]
		then
			continue
		fi

		if [ -f "${arguments[${index}]}" ] &&
		   [ -f "${arguments[${index} + 1]}" ]
		then
			local temp_assertion_error_file="${PWD}/temp_assertion_error"

			diff \
				--side-by-side \
				--suppress-common-lines \
				"${arguments[${index}]}" "${arguments[${index} + 1]}" > "${temp_assertion_error_file}"

			if [ "${?}" -ne 0 ] && [ "${_TEST_RESULT}" == "true" ]
			then
				_TEST_RESULT="false"

				while IFS= read -r line
				do
					echo "Actual: $(echo "${line}" | cut --delimiter='|' --fields=1 | xargs)" >> "${assertion_error_file}"
					echo -e "Expected: $(echo "${line}" | cut --delimiter='|' --fields=2 | xargs)\n" >> "${assertion_error_file}"
				done < "${temp_assertion_error_file}"
			fi

			rm --force "${temp_assertion_error_file}"
		else
			if [ "${arguments[${index}]}" != "${arguments[${index} + 1]}" ]
			then
				if [ "${_TEST_RESULT}" == "true" ]
				then
					_TEST_RESULT="false"
				fi

				touch "${assertion_error_file}"

				echo "Actual: ${arguments[${index}]}" >> "${assertion_error_file}"
				echo -e "Expected: ${arguments[${index} + 1]}\n" >> "${assertion_error_file}"
			fi
		fi
	done

	if [ -z "${DISPLAY_SUCCESSFUL_TEST_RESULT}" ] && [ "${_TEST_RESULT}" == "true" ]
	then
		_display_test_initial_message

		if _is_test_server
		then
			echo -e "${FUNCNAME[1]} SUCCESS :white_check_mark:\n"

			return
		fi

		echo -e "${FUNCNAME[1]} \e[1;32mSUCCESS\e[0m\n"
	elif [ "${_TEST_RESULT}" == "false" ]
	then
		_display_test_initial_message

		if _is_test_server
		then
			echo -e "${FUNCNAME[1]} FAILED :x:\n"
		else
			echo -e "${FUNCNAME[1]} \e[1;31mFAILED\e[0m\n"
		fi

		cat "${assertion_error_file}"

		rm --force "${assertion_error_file}"

		_TEST_RESULT="true"
	fi
}

function common_set_up {
	LIFERAY_RELEASE_TEST_MODE="true"
}

function common_tear_down {
	unset LIFERAY_RELEASE_TEST_MODE
}

function main {
	_TEST_RESULT="true"
}

function _display_test_initial_message {
	if [ -n "${BASH_SOURCE[3]}" ]
	then
		echo -e "\n### Running tests from $(echo ${BASH_SOURCE[3]} | sed --regexp-extended "s/\.\///g") ###\n"
	elif [ -n "${BASH_SOURCE[2]}" ]
	then
		echo -e "\n### Running tests from $(echo ${BASH_SOURCE[2]} | sed --regexp-extended "s/\.\///g") ###\n"
	fi
}

function _is_test_server {
	if [[ "$(hostname)" =~ ^test-[0-9]+-[0-9]+(-[0-9]+)? ]]
	then
		return 0
	fi

	return 1
}

main