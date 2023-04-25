#!/bin/bash

function download_released_files {
	lcd /opt/liferay/dev/projects/liferay-portal-ee/modules/.releng

	echo "Downloading artifacts"

	find . -name artifact.properties -print0 | while IFS= read -r -d '' artifact_properties
	do
		if [ ! -e ../$(dirname "${artifact_properties}")/.lfrbuild-portal ]
		then
			echo "Skipping $(dirname) as it doesn't have .lfrbuild-portal"

			continue
		fi

		local url=$(read_property "${artifact_properties}" "artifact.url")

		local file_name=$(basename "${url}")

		if (! download "${url}" "${BUNDLES_DIR}/osgi/marketplace/${file_name}")
		then
			echo "Failed to download ${url}."

			exit 1
		fi
	done
}