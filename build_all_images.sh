#!/bin/bash

function main {
	local release_file_urls=(
		releases.liferay.com/portal/6.2.5-ga6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip
		releases.liferay.com/portal/7.0.6-ga7/liferay-ce-portal-tomcat-7.0-ga7-20180507111753223.zip
		releases.liferay.com/portal/7.1.0-ga1/liferay-ce-portal-tomcat-7.1.0-ga1-20180703012531655.zip
		releases.liferay.com/portal/7.1.1-ga2/liferay-ce-portal-tomcat-7.1.1-ga2-20181101125651026.7z
		#releases.liferay.com/portal/snapshot-7.0.x/201808161346/liferay-portal-tomcat-7.0.x.zip
		#releases.liferay.com/portal/snapshot-7.1.x/201809171924/liferay-portal-tomcat-7.1.x.7z
		files.liferay.com/private/ee/portal/6.2.10.21/liferay-portal-tomcat-6.2-ee-sp20-20170717160924965.zip
		files.liferay.com/private/ee/portal/7.0.10.8/liferay-dxp-digital-enterprise-tomcat-7.0-sp8-20180717152749345.zip
		files.liferay.com/private/ee/portal/7.1.10/liferay-dxp-tomcat-7.1.10-ga1-20180703090613030.zip
		#files.liferay.com/private/ee/portal/snapshot-ee-6.2.x/201808160944/liferay-portal-tomcat-ee-6.2.x.zip
		#files.liferay.com/private/ee/portal/snapshot-7.1.x-private/201808162051/liferay-portal-tomcat-7.1.x-private.zip
	)

	for release_file_url in ${release_file_urls[@]}
	do
		echo ""
		echo "Building Docker image for ${release_file_url}."
		echo ""

		./build_image.sh ${release_file_url}
	done
}

main