#!/bin/bash

function date {
	export TZ=UTC

	if [ -z ${1+x} ] || [ -z ${2+x} ]
	then
		if [ "$(uname)" == "Darwin" ]
		then
			/bin/date
		elif [ -e /bin/date ]
		then
			/bin/date --iso-8601=seconds
		else
			/usr/bin/date --iso-8601=seconds
		fi
	else
		if [ "$(uname)" == "Darwin" ]
		then
			/bin/date -jf "%a %b %e %H:%M:%S %Z %Y" "${1}" "${2}"
		elif [ -e /bin/date ]
		then
			/bin/date -d "${1}" "${2}"
		else
			/usr/bin/date -d "${1}" "${2}"
		fi
	fi
}

function main {
	local current_date=$(date)

	local backup_dir=$(date "${current_date}" "+%Y-%m/%Y-%m-%d/%Y-%m-%d-%H%M%S")

	backup_dir=/opt/liferay/backups/${backup_dir}

	mkdir -p ${backup_dir}

	echo "Starting backup at ${backup_dir}."

	local timestamp=$(date "${current_date}" "+%Y%m%d%H%M%S")

	backup_db.sh ${backup_dir} ${timestamp} &

	backup_document_library.sh ${backup_dir} ${timestamp} &

	wait

	echo "Exited backup at ${backup_dir}."

	ls -hl ${backup_dir}
}

main "${@}"
