#!/bin/bash

function install_success {
	echo ""
	echo "[LIFERAY] Patching Tool was succesfully installed."
}

function main {
	if [ -e ${LIFERAY_PATCHING_DIR}/patching-tool-* ]
	then
		echo ""
		echo "[LIFERAY] Updating Patching Tool."

		mv /opt/liferay/patching-tool/patches /opt/liferay/patching-tool-upgrade-patches

		rm -fr /opt/liferay/patching-tool

		unzip -d /opt/liferay -q ${LIFERAY_PATCHING_DIR}/patching-tool-*

		/opt/liferay/patching-tool/patching-tool.sh auto-discovery

		rm -fr /opt/liferay/patching-tool/patches

		mv /opt/liferay/patching-tool-upgrade-patches /opt/liferay/patching-tool/patches
	fi

	if [ -e ${LIFERAY_PATCHING_DIR}/liferay-*.zip ]
	then
		if [ `ls ${LIFERAY_PATCHING_DIR}/liferay-*.zip | wc -l` == 1 ]
		then
			if ( /opt/liferay/patching-tool/patching-tool.sh apply ${LIFERAY_PATCHING_DIR}/liferay-*.zip )
			then
				install_success
			else
				run_install
			fi
		else
			run_install
		fi
	fi
}

function run_install {
	cp ${LIFERAY_PATCHING_DIR}/liferay-*.zip /opt/liferay/patching-tool/patches

	if ( /opt/liferay/patching-tool/patching-tool.sh install )
	then
		install_success
	fi
}

main