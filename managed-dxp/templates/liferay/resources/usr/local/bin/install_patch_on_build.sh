#!/bin/bash

if [ $(find "/opt/liferay/patching-tool/patches" -maxdepth 1 -type f -name "liferay-*.zip" | wc -l) == 1 ]
then
	/opt/liferay/patching-tool/patching-tool.sh install

	rm -fr /opt/liferay/osgi/state
fi