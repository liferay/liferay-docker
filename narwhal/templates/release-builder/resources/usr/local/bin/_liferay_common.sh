#!/bin/bash

SKIPPED=5

function background_run {
	if [ -n "${NARWHAL_DEBUG}" ]
	then
		time_run "${@}"
	else
		time_run "${@}" &
	fi
}

function download {
	url=${1}
	file=${2}

	if [ -e "${file}" ]
	then
		echo "Skipping the download of ${url} as it already exists."

		return
	fi

	cache_file=/opt/liferay/download_cache/${url##*://}

	if [ -e "${cache_file}" ]
	then
		echo "Copying file from cache: ${cache_file}"

		cp "${cache_file}" "${file}"

		return
	fi

	mkdir -p $(dirname "${cache_file}")

	echo "Downloading ${url}"

	if (! curl "${url}" --output "${cache_file}_temp" --silent)
	then
		echo "Downloading ${url} was unsuccessful, exiting."

		return 4
	else
		mv "${cache_file}_temp" "${cache_file}"

		cp "${cache_file}" "${file}"
	fi
}

function echo_time {
	local seconds=${1}

	printf '%02dh:%02dm:%02ds' $((seconds/3600)) $((seconds%3600/60)) $((seconds%60))
}

function lcd {
	cd "${1}" || exit 3
}

function next_step {
	local step=$(cat "${BUILD_DIR}"/.step)

	step=$((step + 1))

	echo ${step} > "${BUILD_DIR}"/.step

	printf '%02d' ${step}
}

function read_bnd_property {
	file=${1}
	property=${2}

	local value=$(grep -F "${2}: " "${1}")

	echo "${value##*: }"
}

function read_property {
	file=${1}
	property=${2}

	local value=$(grep -F "${2}=" "${1}")

	echo "${value##*=}"
}

function time_run {
	local run_id=$(echo "${@}" | tr " " "_")
	local start_time=$(date +%s)

	local log_file="${BUILD_DIR}/build_${start_time}_step_$(next_step)_${run_id}.txt"

	echo "$(date) > ${*}"

	if [ ! -n "${NARWHAL_DEBUG}" ]
	then
		"${@}" &> "${log_file}"
	else
		"${@}"
	fi

	local exit_code=${?}

	local end_time=$(date +%s)

	if [ "${exit_code}" == "${SKIPPED}" ]
	then
		echo "$(date) < ${*} - skip"
	else
		local seconds=$((end_time - start_time))

		if [ "${exit_code}" -gt 0 ]
		then
			echo "$(date) ! ${*} exited with error in $(echo_time ${seconds}) (exit code: ${exit_code})."

			if [ ! -n "${NARWHAL_DEBUG}" ]
			then
				echo "Full log file: ${log_file}. Printing the last 100 lines:"

				tail -n 100 "${log_file}"
			fi

			exit ${exit_code}
		else 
			echo "$(date) < ${*} - success in $(echo_time ${seconds})"
		fi
	fi
}
