#/bin/bash

set -e

function backup {
	echo "Starting document library backup."

	cd "/opt/liferay/shared-volume/"

	tar cz document-library > "${BACKUP_DIR}/document-library-${TIMESTAMP}.tar.gz"

	echo "Filesystem backup is completed successfully."
}

function check_usage {
	BACKUP_DIR="${1}"
	TIMESTAMP="${2}"
}

function main {
	check_usage ${@}

	backup
}

main ${@}