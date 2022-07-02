#!/bin/bash

function check_usage {
	CURRENT_DATE=$(date)

	TIMESTAMP=$(date "${CURRENT_DATE}" "+%Y%m%d%H%M%S")
	BACKUP_DIR=$(date "${CURRENT_DATE}" "+%Y-%m/%Y-%m-%d/%Y-%m-%d-%H%M%S")
	BACKUP_DIR="/opt/liferay/backups/${BACKUP_DIR}"

	mkdir -p "${BACKUP_DIR}"
}

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

function execute_backups {
	backup_db.sh "${BACKUP_DIR}" "${TIMESTAMP}" &

	backup_document_library.sh "${BACKUP_DIR}" "${TIMESTAMP}" &

	wait

	echo "Both backup jobs have exited, backup directory: ${BACKUP_DIR}."

	ls -lh "${BACKUP_DIR}"
}

function main {
	check_usage ${@}

	execute_backups
}

main ${@}