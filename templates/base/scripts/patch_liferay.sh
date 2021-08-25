#!/bin/bash

function apply_patch {
	local patch_file_name=${1}

	if [ -e "/opt/liferay/patching-tool/patch-applied" ]
	then
		local installed_patch=$(cat /opt/liferay/patching-tool/patch-applied)

		if [ ! "${patch_file_name}" == "${installed_patch}" ]
		then
			echo ""
			echo "[LIFERAY] ${patch_file_name} cannot be applied on this container because ${installed_patch} is already installed. Remove ${patch_file_name} from the patching directory to disable this warning message."
		fi
	elif (! (echo "${patch_file_name}" | grep -q "7310.zip") && /opt/liferay/patching-tool/patching-tool.sh apply "${LIFERAY_PATCHING_DIR}/${patch_file_name}")
	then
		echo" ${patch_file_name}" > /opt/liferay/patching-tool/patch-applied

		install_patch_step_2
	else
		install_patch_step_1 "${patch_file_name}"
	fi
}

function install_patch_step_1 {
	local patch_file_name="${1}"

	cp "${LIFERAY_PATCHING_DIR}/${patch_file_name}" /opt/liferay/patching-tool/patches

	/opt/liferay/patching-tool/patching-tool.sh setup

	if (/opt/liferay/patching-tool/patching-tool.sh install -force)
	then
		install_patch_step_2
	fi
}

function install_patch_step_2 {
	rm -fr /opt/liferay/osgi/state/*

	echo ""
	echo "[LIFERAY] Patch applied successfully."
}

function main {
	if [[ $(ls -A "${LIFERAY_PATCHING_DIR}"/patching-tool-*.zip 2>/dev/null) ]]
	then
		echo ""
		echo "[LIFERAY] Updating Patching Tool."

		mv /opt/liferay/patching-tool/patches /opt/liferay/patching-tool-upgrade-patches

		rm -fr /opt/liferay/patching-tool

		unzip -d /opt/liferay -q "${LIFERAY_PATCHING_DIR}"/patching-tool-*

		/opt/liferay/patching-tool/patching-tool.sh auto-discovery ../tomcat

		rm -fr /opt/liferay/patching-tool/patches

		mv /opt/liferay/patching-tool-upgrade-patches /opt/liferay/patching-tool/patches

		echo ""
		echo "[LIFERAY] Patching Tool updated successfully."
	fi

	if [[ $(find "${LIFERAY_PATCHING_DIR}" -maxdepth 1 -type f -name "liferay-*.zip" 2>/dev/null) ]]
	then
		if [ $(find "${LIFERAY_PATCHING_DIR}" -maxdepth 1 -type f -name "liferay-*.zip" | wc -l) == 1 ]
		then
			local patch_file_name=$(basename "${LIFERAY_PATCHING_DIR}"/liferay-*.zip)

			apply_patch "${patch_file_name}"
		else
			local patch_file_name=$(basename $(find "${LIFERAY_PATCHING_DIR}" -maxdepth 1 -name "liferay-*.zip" -type f 2>/dev/null | sort | tail -n 1))

			echo ""
			echo "[LIFERAY] There were multiple hotfixes in the patching folder. As only one can be installed, applying the latest one: ${patch_file_name}."

			apply_patch "${patch_file_name}"
		fi
	fi
}

main