#!/bin/bash

function copy_build {
	rm -fr "${BUILD_DIR}/bundles"

	cp -a "${BUNDLES_DIR}" "${BUILD_DIR}"

	BUNDLES_DIR="${BUILD_DIR}/bundles"
}

function download_released_files {
	lcd /opt/liferay/dev/projects/liferay-portal-ee/modules/.releng

	echo "Downloading artifacts"

	find . -name artifact.properties -print0 | while IFS= read -r -d '' artifact_properties
	do
		echo "Processing ${artifact_properties}"
		local app_dir=../$(dirname "${artifact_properties}")

		if [ ! -e "${app_dir}/.lfrbuild-portal" ]
		then
			echo "Skipping $(dirname) as it doesn't have .lfrbuild-portal"

			continue
		fi

		if [ -e "${app_dir}/.lfrbuild-app-server-lib" ]
		then
			echo "Skipping $(dirname) as it has .lfrbuild-app-server-lib"

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
		built_name=${built_name#./}

		local built_file=$(find "${BUNDLES_DIR}/osgi" -name "${built_name}")

		if [ -n "${built_file}" ]
		then
			echo "Deleting ${built_file}"

			rm -f "${built_file}"
		else
			echo "Couldn't find ${built_name}"

			return 1
		fi

	done
}