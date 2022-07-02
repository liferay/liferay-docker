#!/bin/bash

if [ -n "${LIFERAY_ANTIVIRUS_ADDRESS}" ]
then
	local hostname=${LIFERAY_ANTIVIRUS_ADDRESS%%:*}

	echo "hostname=\"${hostname}\"" > "/opt/liferay/osgi/configs/com.liferay.antivirus.clamd.scanner.internal.configuration.ClamdAntivirusScannerConfiguration.config"
	echo "port=I\"3310\"" >> "/opt/liferay/osgi/configs/com.liferay.antivirus.clamd.scanner.internal.configuration.ClamdAntivirusScannerConfiguration.config"
	echo "timeout=I\"10000\"" >> "/opt/liferay/osgi/configs/com.liferay.antivirus.clamd.scanner.internal.configuration.ClamdAntivirusScannerConfiguration.config"
fi