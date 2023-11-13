#!/bin/bash

set -e

function main {
	echo "Starting document library backup."

	cd /opt/liferay/data

	tar cz document-library > ${1}/document-library-${2}.tar.gz

	echo "Document library backup was completed successfully."
}

main "${@}"
