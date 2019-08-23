#!/bin/bash
function main {
	if [ -e ${LIFERAY_PATCHING_DIR}/patching-tool-* ]
	then
		echo ""
		echo "[LIFERAY] Updating Patching Tool."

		mv /opt/liferay/patching-tool/patches /opt/liferay/patching-tool-upgrade-patches
		rm -rf /opt/liferay/patching-tool
		unzip -d /opt/liferay -q ${LIFERAY_PATCHING_DIR}/patching-tool-*

		/opt/liferay/patching-tool/patching-tool.sh auto-discovery

		rm -rf /opt/liferay/patching-tool/patches
		mv /opt/liferay/patching-tool-upgrade-patches /opt/liferay/patching-tool/patches
	fi
}

main