#!/bin/bash

source ./_common.sh

BUILD_ALL_IMAGES_PUSH=${1}

function build_image {

	#
	# LIFERAY_DOCKER_IMAGE_FILTER="7.2.10-dxp-1 "  ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=7.2.10 ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=commerce ./build_all_images.sh
	#

	if [ -n "${LIFERAY_DOCKER_IMAGE_FILTER}" ] && [[ ! $(echo ${1} ${2} ${3} ${4} | grep ${LIFERAY_DOCKER_IMAGE_FILTER}) ]]
	then
		return
	fi

	if [ ! -n "${1}" ]
	then
		local build_id=${2##*/}
	else
		local build_id=${1}
	fi

	echo ""
	echo "Building Docker image ${build_id} based on ${2}."
	echo ""

	{
		LIFERAY_DOCKER_FIX_PACK_URL=${3} LIFERAY_DOCKER_RELEASE_FILE_URL=${2} LIFERAY_DOCKER_RELEASE_VERSION=${1} LIFERAY_DOCKER_TEST_HOTFIX_URL=${5} LIFERAY_DOCKER_TEST_INSTALLED_PATCHES=${4} time ./build_image.sh ${BUILD_ALL_IMAGES_PUSH} 2>&1

		if [ $? -gt 0 ]
		then
			echo "FAILED: ${build_id}" >> ${LOGS_DIR}/results
		else
			echo "SUCCESS: ${build_id}" >> ${LOGS_DIR}/results
		fi
	} | tee ${LOGS_DIR}/${build_id}".log"
}

function build_images_dxp_70 {
	build_image \
		7.0.10-ga1 \
		files.liferay.com/private/ee/portal/7.0.10/liferay-dxp-digital-enterprise-tomcat-7.0-ga1-20160617092557801.zip \
		"" \
		""

	for fix_pack_id in {88..89}
	do
		build_image \
			7.0.10-de-${fix_pack_id} \
			files.liferay.com/private/ee/portal/7.0.10.12/liferay-dxp-digital-enterprise-tomcat-7.0.10.12-sp12-20191014182832691.7z \
			files.liferay.com/private/ee/fix-packs/7.0.10/de/liferay-fix-pack-de-${fix_pack_id}-7010.zip \
			de-${fix_pack_id}-7010
	done

	build_image \
		7.0.10-sp13 \
		files.liferay.com/private/ee/portal/7.0.10.13/liferay-dxp-digital-enterprise-tomcat-7.0.10.13-sp13-slim-20200310164407389.7z \
		"" \
		de-90-7010
}

function build_images_dxp_71 {
	build_image \
		7.1.10-ga1 \
		files.liferay.com/private/ee/portal/7.1.10/liferay-dxp-tomcat-7.1.10-ga1-20180703090613030.zip \
		"" \
		""

	for fix_pack_id in {1..4}
	do
		build_image \
			7.1.10-dxp-${fix_pack_id} \
			files.liferay.com/private/ee/portal/7.1.10/liferay-dxp-tomcat-7.1.10-ga1-20180703090613030.zip \
			files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip \
			dxp-${fix_pack_id}-7110
	done

	build_image \
		7.1.10-sp1 \
		files.liferay.com/private/ee/portal/7.1.10.1/liferay-dxp-tomcat-7.1.10.1-sp1-20190110085705206.zip \
		"" \
		dxp-5-7110

	for fix_pack_id in {6..9}
	do
		build_image \
			7.1.10-dxp-${fix_pack_id} \
			files.liferay.com/private/ee/portal/7.1.10.1/liferay-dxp-tomcat-7.1.10.1-sp1-20190110085705206.zip \
			files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip \
			dxp-${fix_pack_id}-7110
	done

	build_image \
		7.1.10-sp2 \
		files.liferay.com/private/ee/portal/7.1.10.2/liferay-dxp-tomcat-7.1.10.2-sp2-20190422172027516.zip \
		"" \
		dxp-10-7110

	for fix_pack_id in {11..14}
	do
		build_image \
			7.1.10-dxp-${fix_pack_id} \
			files.liferay.com/private/ee/portal/7.1.10.2/liferay-dxp-tomcat-7.1.10.2-sp2-20190422172027516.zip \
			files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip \
			dxp-${fix_pack_id}-7110
	done

	build_image \
		7.1.10-sp3 \
		files.liferay.com/private/ee/portal/7.1.10.3/liferay-dxp-tomcat-7.1.10.3-sp3-slim-20191118185746787.7z \
		"" \
		dxp-15-7110

	for fix_pack_id in {16..16}
	do
		build_image \
			7.1.10-dxp-${fix_pack_id} \
			files.liferay.com/private/ee/portal/7.1.10.3/liferay-dxp-tomcat-7.1.10.3-sp3-20191118185746787.7z \
			files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip \
			dxp-${fix_pack_id}-7110
	done
}

function build_images_dxp_72 {
	build_image \
		7.2.10-ga1 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		"" \
		""

	build_image \
		7.2.10-dxp-1 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/dxp/liferay-fix-pack-dxp-1-7210.zip \
		dxp-1-7210

	build_image \
		7.2.10-sp1 \
		files.liferay.com/private/ee/portal/7.2.10.1/liferay-dxp-tomcat-7.2.10.1-sp1-slim-20191009103614075.7z \
		"" \
		dxp-2-7210

	build_image \
		7.2.10-dxp-3 \
		files.liferay.com/private/ee/portal/7.2.10.1/liferay-dxp-tomcat-7.2.10.1-sp1-20191009103614075.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/dxp/liferay-fix-pack-dxp-3-7210.zip \
		dxp-3-7210

	build_image \
		7.2.10-dxp-4 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-4/liferay-dxp-tomcat-7.2.10-dxp-4-slim-20200121112425051.7z \
		"" \
		dxp-4-7210,hotfix-1072-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-1072-7210.zip
}

function main {
	LOGS_DIR=logs-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p ${LOGS_DIR}

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
		#files.liferay.com/private/ee/portal/snapshot-ee-6.2.x/201808160944/liferay-portal-tomcat-ee-6.2.x.zip
		#files.liferay.com/private/ee/portal/snapshot-7.1.x-private/201808162051/liferay-portal-tomcat-7.1.x-private.zip
	)

	for release_file_url in ${release_file_urls[@]}
	do
		build_image "" ${release_file_url} "" ""
	done

	build_images_dxp_70
	build_images_dxp_71
	build_images_dxp_72

	echo ""
	echo "Results: "
	echo ""

	cat ${LOGS_DIR}/results
}

main