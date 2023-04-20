#!/bin/bash

function download_released_files {
	lcd /opt/liferay/dev/projects/liferay-portal-ee/modules/.releng

	echo "Downloading artifacts"

	find . -name artifact.properties -print0 | while IFS= read -r -d '' artifact_properties
	do
		local url=$(grep "artifact.url=" "${artifact_properties}")
		url=${url##artifact.url=}

		local file_name=$(basename "${url}")

		download "${url}" "${BUNDLES_DIR}/osgi/modules/${file_name}"
	done
}