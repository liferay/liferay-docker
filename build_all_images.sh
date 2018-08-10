#!/bin/bash

function main {
	local release_file_urls=(
		#releases.liferay.com/portal/6.2.5-ga6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip
		#releases.liferay.com/portal/7.0.6-ga7/liferay-ce-portal-tomcat-7.0-ga7-20180507111753223.zip
		#releases.liferay.com/portal/7.1.0-ga1/liferay-ce-portal-tomcat-7.1.0-ga1-20180703012531655.zip
		#files.liferay.com/private/ee/portal/6.2.10.21/liferay-portal-tomcat-6.2-ee-sp20-20170717160924965.zip
		files.liferay.com/private/ee/portal/7.0.10.8/liferay-dxp-digital-enterprise-tomcat-7.0-sp8-20180717152749345.zip
		#files.liferay.com/private/ee/portal/7.1.10/liferay-dxp-tomcat-7.1.10-ga1-20180703090613030.zip

		#releases.liferay.com/portal/nightly-master/20180312011850065/liferay-ce-portal-tomcat-7.0-nightly-63becb8353e57714bf179233e4b54ad73d6919b1.zip
	)

	for release_file_url in ${release_file_urls[@]}
	do
		echo ""
		echo "Building Docker image for ${release_file_urls}."
		echo ""

		./build_image.sh ${release_file_url}
	done
}

main