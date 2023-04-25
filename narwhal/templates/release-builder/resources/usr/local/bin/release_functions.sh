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

function remove_built_jars {
	lcd "${BUNDLES_DIR}/osgi/marketplace"

	find . -name "*.jar" -print0 | while IFS= read -r -d '' marketplace_jar
	do
		local built_name=$(echo "${marketplace_jar}" | sed -e s/-[0-9]*[.][0-9]*[.][0-9]*.jar/.jar/)

		if [ -e "${BUNDLES_DIR}/osgi/modules/${built_name}" ]
		then
			echo "Deleting ${BUNDLES_DIR}/osgi/modules/${built_name}"

			rm -f "${BUNDLES_DIR}/osgi/modules/${built_name}"
		else
			if [ -e "${BUNDLES_DIR}/osgi/test/${built_name}" ]
			then
				echo "Deleting ${BUNDLES_DIR}/osgi/test/${built_name}"

				rm -f "${BUNDLES_DIR}/osgi/test/${built_name}"
			else
				echo "Module ${built_name} was not built."

				return 1
			fi
		fi
	done
}