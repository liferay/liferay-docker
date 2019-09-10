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

	if [ -e ${LIFERAY_PATCHING_DIR}/liferay-*.zip ]
	then
		local run_install=false
		local install_success=false

		if [ `ls ${LIFERAY_PATCHING_DIR}/liferay-*.zip | wc -l` == 1 ]
		then
			if ( /opt/liferay/patching-tool/patching-tool.sh apply ${LIFERAY_PATCHING_DIR}/liferay-*.zip )
			then
				install_success=true
			else
				run_install=true
			fi
		else
			run_install=true
		fi

		if ( ${run_install} )
		then
			cp ${LIFERAY_PATCHING_DIR}/liferay-*.zip /opt/liferay/patching-tool/patches

			if ( /opt/liferay/patching-tool/patching-tool.sh install )
			then
				install_success=true
			fi
		fi

		if ( ${install_success} )
		then
			echo ""
			echo "[LIFERAY] Patch installation was successful."
		else
			exit 1
		fi
	fi
}

main