#!/bin/bash

function build_image {
	echo ""
	echo "Building Docker image for ${2}."
	echo ""

	LIFERAY_DOCKER_FIX_PACK_URL=${3} LIFERAY_DOCKER_RELEASE_VERSION=${1} LIFERAY_DOCKER_RELEASE_FILE_URL=${2} ./build_image.sh push
}

function build_images_dxp_72 {
	build_image \
		7.2.10-ga1 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		""

	build_image \
		7.2.10-dxp-1 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/dxp/liferay-fix-pack-dxp-1-7210.zip

	build_image \
		7.2.10-dxp-2 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/dxp/liferay-fix-pack-dxp-2-7210.zip

	build_image \
		7.2.10-sp1
		files.liferay.com/private/ee/portal/7.2.10.1/liferay-dxp-tomcat-7.2.10.1-sp1-slim-20191009103614075.7z \
		""

	build_image \
		7.2.10-dxp-4 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-4/liferay-dxp-tomcat-7.2.10-dxp-4-slim-20200121112425051.7z \
		""
}

function main {
	local release_file_urls=(
		releases.liferay.com/commerce/2.0.7/liferay-commerce-2.0.7-7.2.x-201912261227.7z
		files.liferay.com/private/ee/commerce/2.0.7/7.1/liferay-commerce-enterprise-2.0.7-7.1.x-202003021149.7z
		files.liferay.com/private/ee/commerce/2.0.7/7.2/liferay-commerce-enterprise-2.0.7-7.2.x-201912261238.7z
		releases.liferay.com/portal/6.1.2-ga3/liferay-portal-tomcat-6.1.2-ce-ga3-20130816114619181.zip
		files.liferay.com/private/ee/portal/6.1.30.5/liferay-portal-tomcat-6.1-ee-ga3-sp5-20160201142343123.zip
		releases.liferay.com/portal/6.2.5-ga6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip
		files.liferay.com/private/ee/portal/6.2.10.21/liferay-portal-tomcat-6.2-ee-sp20-20170717160924965.zip
		releases.liferay.com/portal/7.0.6-ga7/liferay-ce-portal-tomcat-7.0-ga7-20180507111753223.zip
		releases.liferay.com/portal/7.1.3-ga4/liferay-ce-portal-tomcat-7.1.3-ga4-20190508171117552.7z
		releases.liferay.com/portal/7.2.1-ga2/liferay-ce-portal-tomcat-7.2.1-ga2-20191111141448326.7z
		releases.liferay.com/portal/7.3.0-ga1/liferay-ce-portal-tomcat-7.3.0-ga1-20200127150653953.7z
		#releases.liferay.com/portal/snapshot-7.1.x/201902130905/liferay-portal-tomcat-7.1.x.7z
		#releases.liferay.com/portal/snapshot-master/201902131509/liferay-portal-tomcat-master.7z
		files.liferay.com/private/ee/portal/7.0.10.11/liferay-dxp-digital-enterprise-tomcat-7.0.10.11-sp11-20190506123513875.zip
		files.liferay.com/private/ee/portal/7.1.10.2/liferay-dxp-tomcat-7.1.10.2-sp2-20190422172027516.zip
		#files.liferay.com/private/ee/portal/snapshot-ee-6.2.x/201808160944/liferay-portal-tomcat-ee-6.2.x.zip
		#files.liferay.com/private/ee/portal/snapshot-7.1.x-private/201808162051/liferay-portal-tomcat-7.1.x-private.zip
	)

	for release_file_url in ${release_file_urls[@]}
	do
		build_image "" ${release_file_url} ""
	done

	build_images_dxp_72
}

main