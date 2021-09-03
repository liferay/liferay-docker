#!/bin/bash

source ./_common.sh

BUILD_ALL_IMAGES_PUSH=${1}

function build_base_image {
	local base_image_version=$(docker image inspect --format '{{index .Config.Labels "org.label-schema.version"}}' liferay/base:latest)

	if [[ ${base_image_version} == $(./release_notes.sh get-version) ]]
	then
		return
	fi

	docker pull liferay/base:latest

	base_image_version=$(docker image inspect --format '{{index .Config.Labels "org.label-schema.version"}}' liferay/base:latest)

	if [[ ${base_image_version} == $(./release_notes.sh get-version) ]]
	then
		return
	fi

	echo ""
	echo "Building Docker image base."
	echo ""

	time ./build_base_image.sh "${BUILD_ALL_IMAGES_PUSH}" | tee -a "${LOGS_DIR}"/base.log

	if [ "${PIPESTATUS[0]}" -gt 0 ]
	then
		echo "FAILED: base" >> "${LOGS_DIR}/results"

		exit 1
	else
		echo "SUCCESS: base" >> "${LOGS_DIR}/results"
	fi
}

function build_bundle_image {

	#
	# LIFERAY_DOCKER_IMAGE_FILTER="7.2.10-dxp-1 "  ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=7.2.10 ./build_all_images.sh
	# LIFERAY_DOCKER_IMAGE_FILTER=commerce ./build_all_images.sh
	#

	if [ -n "${LIFERAY_DOCKER_IMAGE_FILTER}" ] && [[ ! $(echo "${1} ${2} ${3} ${4}" | grep "${LIFERAY_DOCKER_IMAGE_FILTER}") ]]
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

	LIFERAY_DOCKER_FIX_PACK_URL=${3} LIFERAY_DOCKER_RELEASE_FILE_URL=${2} LIFERAY_DOCKER_RELEASE_VERSION=${1} LIFERAY_DOCKER_TEST_HOTFIX_URL=${5} LIFERAY_DOCKER_TEST_INSTALLED_PATCHES=${4} time ./build_bundle_image.sh "${BUILD_ALL_IMAGES_PUSH}" 2>&1 | tee "${LOGS_DIR}/${build_id}.log"

	local build_bundle_image_exit_code=${PIPESTATUS[0]}

	if [ "${build_bundle_image_exit_code}" -gt 0 ]
	then
		echo "FAILED: ${build_id}" >> "${LOGS_DIR}/results"

		if [ "${build_bundle_image_exit_code}" -eq 4 ]
		then
			echo "Detected a license failure while building image ${build_id}." > "${LOGS_DIR}/license-failure"

			echo "There is an existing license failure."

			exit 4
		fi
	else
		echo "SUCCESS: ${build_id}" >> "${LOGS_DIR}/results"
	fi

	exit 1
}

function build_bundle_images_dxp_70 {
	build_bundle_image \
		7.0.10-ga1 \
		files.liferay.com/private/ee/portal/7.0.10/liferay-dxp-digital-enterprise-tomcat-7.0-ga1-20160617092557801.zip \
		"" \
		""

	build_bundle_image \
		7.0.10-de-27 \
		files.liferay.com/private/ee/portal/7.0.10.4/liferay-dxp-digital-enterprise-tomcat-7.0-sp4-20170705142422877.zip \
		files.liferay.com/private/ee/fix-packs/7.0.10/de/liferay-fix-pack-de-27-7010.zip \
		de-27-7010

	for fix_pack_id in {88..89}
	do
		build_bundle_image \
			"7.0.10-de-${fix_pack_id}" \
			files.liferay.com/private/ee/portal/7.0.10.12/liferay-dxp-digital-enterprise-tomcat-7.0.10.12-sp12-20191014182832691.7z \
			"files.liferay.com/private/ee/fix-packs/7.0.10/de/liferay-fix-pack-de-${fix_pack_id}-7010.zip" \
			"de-${fix_pack_id}-7010"
	done

	build_bundle_image \
		7.0.10-de-90,7.0.10-sp13 \
		files.liferay.com/private/ee/portal/7.0.10.13/liferay-dxp-digital-enterprise-tomcat-7.0.10.13-sp13-slim-20200310164407389.7z \
		"" \
		de-90-7010

	build_bundle_image \
		7.0.10-de-91 \
		files.liferay.com/private/ee/portal/7.0.10-de-91/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-91-slim-20200420163527702.7z \
		"" \
		de-91-7010,hotfix-6871-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-6871-7010.zip

	build_bundle_image \
		7.0.10-security-de-91-202003-1 \
		files.liferay.com/private/ee/portal/7.0.10-de-91/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-91-20200420163527702.7z \
		files.liferay.com/private/ee/fix-packs/7.0.10/security-de/liferay-security-de-91-202003-1-7010.zip \
		de-91-7010,security-de-91-202003-1-7010

	build_bundle_image \
		7.0.10-de-92 \
		files.liferay.com/private/ee/portal/7.0.10-de-92/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-92-slim-20200519134012683.7z \
		"" \
		de-92-7010,hotfix-6854-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-6854-7010.zip

	build_bundle_image \
		7.0.10-security-de-92-202004-2 \
		files.liferay.com/private/ee/portal/7.0.10-de-92/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-92-20200519134012683.7z \
		files.liferay.com/private/ee/fix-packs/7.0.10/security-de/liferay-security-de-92-202004-2-7010.zip \
		de-92-7010,security-de-92-202004-2-7010

	build_bundle_image \
		7.0.10-de-93,7.0.10-sp14 \
		files.liferay.com/private/ee/portal/7.0.10.14/liferay-dxp-digital-enterprise-tomcat-7.0.10.14-sp14-slim-20200708121519436.7z \
		"" \
		de-93-7010

	build_bundle_image \
		7.0.10-de-94 \
		files.liferay.com/private/ee/portal/7.0.10-de-94/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-94-slim-20200824095125278.7z \
		"" \
		de-94-7010,hotfix-7623-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-7623-7010.zip

	build_bundle_image \
		7.0.10-de-95 \
		files.liferay.com/private/ee/portal/7.0.10-de-95/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-95-slim-20200925114352092.7z \
		"" \
		de-95-7010,hotfix-7683-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-7683-7010.zip

	build_bundle_image \
		7.0.10-de-96,7.0.10-sp15 \
		files.liferay.com/private/ee/portal/7.0.10.15/liferay-dxp-digital-enterprise-tomcat-7.0.10.15-sp15-slim-20201027133245711.7z \
		"" \
		de-96-7010,hotfix-7777-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-7777-7010.zip

	build_bundle_image \
		7.0.10-de-97 \
		files.liferay.com/private/ee/portal/7.0.10-de-97/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-97-slim-20210204052206153.7z \
		"" \
		de-97-7010,hotfix-7996-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-7996-7010.zip

	build_bundle_image \
		7.0.10-de-98 \
		files.liferay.com/private/ee/portal/7.0.10-de-98/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-98-slim-20210310205342362.7z \
		"" \
		de-98-7010,hotfix-8081-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-8081-7010.zip

	build_bundle_image \
		7.0.10-de-99,7.0.10-sp16 \
		files.liferay.com/private/ee/portal/7.0.10.16/liferay-dxp-digital-enterprise-tomcat-7.0.10.16-sp16-slim-20210422121811252.7z \
		"" \
		de-99-7010,hotfix-8205-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-8205-7010.zip

	build_bundle_image \
		7.0.10-de-100 \
		files.liferay.com/private/ee/portal/7.0.10-de-100/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-100-slim-20210602170649068.7z \
		"" \
		de-100-7010,hotfix-8262-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-8262-7010.zip

	build_bundle_image \
		7.0.10-de-101 \
		files.liferay.com/private/ee/portal/7.0.10-de-101/liferay-dxp-digital-enterprise-tomcat-7.0.10-de-101-slim-20210713081427192.7z \
		"" \
		de-101-7010,hotfix-8457-7010 \
		files.liferay.com/private/ee/fix-packs/7.0.10/hotfix/liferay-hotfix-8457-7010.zip
}

function build_bundle_images_dxp_71 {
	build_bundle_image \
		7.1.10-ga1 \
		files.liferay.com/private/ee/portal/7.1.10/liferay-dxp-tomcat-7.1.10-ga1-20180703090613030.zip \
		"" \
		""

	for fix_pack_id in {1..4}
	do
		build_bundle_image \
			"7.1.10-dxp-${fix_pack_id}" \
			files.liferay.com/private/ee/portal/7.1.10/liferay-dxp-tomcat-7.1.10-ga1-20180703090613030.zip \
			"files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip" \
			"dxp-${fix_pack_id}-7110"
	done

	build_bundle_image \
		7.1.10-dxp-5,7.1.10-sp1 \
		files.liferay.com/private/ee/portal/7.1.10.1/liferay-dxp-tomcat-7.1.10.1-sp1-20190110085705206.zip \
		"" \
		dxp-5-7110

	for fix_pack_id in {6..9}
	do
		build_bundle_image \
			"7.1.10-dxp-${fix_pack_id}" \
			files.liferay.com/private/ee/portal/7.1.10.1/liferay-dxp-tomcat-7.1.10.1-sp1-20190110085705206.zip \
			"files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip" \
			"dxp-${fix_pack_id}-7110"
	done

	build_bundle_image \
		7.1.10-dxp-10,7.1.10-sp2 \
		files.liferay.com/private/ee/portal/7.1.10.2/liferay-dxp-tomcat-7.1.10.2-sp2-20190422172027516.zip \
		"" \
		dxp-10-7110

	for fix_pack_id in {11..14}
	do
		build_bundle_image \
			"7.1.10-dxp-${fix_pack_id}" \
			files.liferay.com/private/ee/portal/7.1.10.2/liferay-dxp-tomcat-7.1.10.2-sp2-20190422172027516.zip \
			"files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip" \
			"dxp-${fix_pack_id}-7110"
	done

	build_bundle_image \
		7.1.10-dxp-15,7.1.10-sp3 \
		files.liferay.com/private/ee/portal/7.1.10.3/liferay-dxp-tomcat-7.1.10.3-sp3-slim-20191118185746787.7z \
		"" \
		dxp-15-7110

	for fix_pack_id in {16..16}
	do
		build_bundle_image \
			"7.1.10-dxp-${fix_pack_id}" \
			files.liferay.com/private/ee/portal/7.1.10.3/liferay-dxp-tomcat-7.1.10.3-sp3-20191118185746787.7z \
			"files.liferay.com/private/ee/fix-packs/7.1.10/dxp/liferay-fix-pack-dxp-${fix_pack_id}-7110.zip" \
			"dxp-${fix_pack_id}-7110"
	done

	build_bundle_image \
		7.1.10-dxp-17,7.1.10-sp4 \
		files.liferay.com/private/ee/portal/7.1.10.4/liferay-dxp-tomcat-7.1.10.4-sp4-slim-20200331093526761.7z \
		"" \
		dxp-17-7110

	build_bundle_image \
		7.1.10-security-dxp-17-202003-3 \
		files.liferay.com/private/ee/portal/7.1.10.4/liferay-dxp-tomcat-7.1.10.4-sp4-20200331093526761.7z \
		files.liferay.com/private/ee/fix-packs/7.1.10/security-dxp/liferay-security-dxp-17-202003-3-7110.zip \
		dxp-17-7110,security-dxp-17-202003-3-7110

	build_bundle_image \
		7.1.10-security-dxp-17-202004-4 \
		files.liferay.com/private/ee/portal/7.1.10.4/liferay-dxp-tomcat-7.1.10.4-sp4-20200331093526761.7z \
		files.liferay.com/private/ee/fix-packs/7.1.10/security-dxp/liferay-security-dxp-17-202004-4-7110.zip \
		dxp-17-7110,security-dxp-17-202004-4-7110

	build_bundle_image \
		7.1.10-dxp-18 \
		files.liferay.com/private/ee/portal/7.1.10-dxp-18/liferay-dxp-tomcat-7.1.10-dxp-18-slim-20200708071442461.7z \
		"" \
		dxp-18-7110,hotfix-4445-7110 \
		files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-4445-7110.zip

	build_bundle_image \
		7.1.10-dxp-19 \
		files.liferay.com/private/ee/portal/7.1.10-dxp-19/liferay-dxp-tomcat-7.1.10-dxp-19-slim-20200910000111431.7z \
		"" \
		dxp-19-7110,hotfix-4673-7110 \
		files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-4673-7110.zip

	build_bundle_image \
		7.1.10-dxp-20,7.1.10-sp5 \
		https://files.liferay.com/private/ee/portal/7.1.10.5/liferay-dxp-tomcat-7.1.10.5-sp5-slim-20201203111512784.7z \
		"" \
		dxp-20-7110,hotfix-5087-7110 \
		http://files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-5087-7110.zip

	build_bundle_image \
		7.1.10-dxp-21 \
		files.liferay.com/private/ee/portal/7.1.10-dxp-21/liferay-dxp-tomcat-7.1.10-dxp-21-slim-20210129112915686.7z \
		"" \
		dxp-21-7110,hotfix-5178-7110 \
		files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-5178-7110.zip

	build_bundle_image \
		7.1.10-dxp-22 \
		files.liferay.com/private/ee/portal/7.1.10-dxp-22/liferay-dxp-tomcat-7.1.10-dxp-22-slim-20210303111136677.7z \
		"" \
		dxp-22-7110,hotfix-5330-7110 \
		files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-5330-7110.zip

	build_bundle_image \
		7.1.10-dxp-23,7.1.10-sp6 \
		files.liferay.com/private/ee/portal/7.1.10.6/liferay-dxp-tomcat-7.1.10.6-sp6-slim-20210507185421428.7z \
		"" \
		dxp-23-7110,hotfix-5503-7110 \
		files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-5503-7110.zip

	build_bundle_image \
		7.1.10-dxp-24 \
		files.liferay.com/private/ee/portal/7.1.10-dxp-24/liferay-dxp-tomcat-7.1.10-dxp-24-slim-20210607121821009.7z \
		"" \
		dxp-24-7110,hotfix-5545-7110 \
		files.liferay.com/private/ee/fix-packs/7.1.10/hotfix/liferay-hotfix-5545-7110.zip
}

function build_bundle_images_dxp_72 {
	build_bundle_image \
		7.2.10-ga1 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		"" \
		""

	build_bundle_image \
		7.2.10-dxp-1 \
		files.liferay.com/private/ee/portal/7.2.10/liferay-dxp-tomcat-7.2.10-ga1-20190531140450482.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/dxp/liferay-fix-pack-dxp-1-7210.zip \
		dxp-1-7210

	build_bundle_image \
		7.2.10-dxp-2,7.2.10-sp1 \
		files.liferay.com/private/ee/portal/7.2.10.1/liferay-dxp-tomcat-7.2.10.1-sp1-slim-20191009103614075.7z \
		"" \
		dxp-2-7210

	build_bundle_image \
		7.2.10-dxp-3 \
		files.liferay.com/private/ee/portal/7.2.10.1/liferay-dxp-tomcat-7.2.10.1-sp1-20191009103614075.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/dxp/liferay-fix-pack-dxp-3-7210.zip \
		dxp-3-7210

	build_bundle_image \
		7.2.10-dxp-4 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-4/liferay-dxp-tomcat-7.2.10-dxp-4-slim-20200121112425051.7z \
		"" \
		dxp-4-7210,hotfix-1167-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-1167-7210.zip

	build_bundle_image \
		7.2.10-security-dxp-4-202003-4 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-4/liferay-dxp-tomcat-7.2.10-dxp-4-20200121112425051.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/security-dxp/liferay-security-dxp-4-202003-4-7210.zip \
		dxp-4-7210,security-dxp-4-202003-4-7210

	build_bundle_image \
		7.2.10-dxp-5,7.2.10-sp2 \
		files.liferay.com/private/ee/portal/7.2.10.2/liferay-dxp-tomcat-7.2.10.2-sp2-slim-20200511121558464.7z \
		"" \
		dxp-5-7210,hotfix-1467-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-1467-7210.zip

	build_bundle_image \
		7.2.10-security-dxp-5-202003-1 \
		files.liferay.com/private/ee/portal/7.2.10.2/liferay-dxp-tomcat-7.2.10.2-sp2-20200511121558464.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/security-dxp/liferay-security-dxp-5-202003-1-7210.zip \
		dxp-5-7210,security-dxp-5-202003-1-7210

	build_bundle_image \
		7.2.10-dxp-6 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-6/liferay-dxp-tomcat-7.2.10-dxp-6-slim-20200611120504742.7z \
		"" \
		dxp-6-7210,hotfix-1992-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-1992-7210.zip

	build_bundle_image \
		7.2.10-security-dxp-6-202004-4 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-6/liferay-dxp-tomcat-7.2.10-dxp-6-20200611120504742.7z \
		files.liferay.com/private/ee/fix-packs/7.2.10/security-dxp/liferay-security-dxp-6-202004-4-7210.zip \
		dxp-6-7210,security-dxp-6-202004-4-7210

	build_bundle_image \
		7.2.10-dxp-7 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-7/liferay-dxp-tomcat-7.2.10-dxp-7-slim-20200727205713822.7z \
		"" \
		dxp-7-7210,hotfix-2457-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-2457-7210.zip

	build_bundle_image \
		7.2.10-dxp-8,7.2.10-sp3 \
		files.liferay.com/private/ee/portal/7.2.10.3/liferay-dxp-tomcat-7.2.10.3-sp3-slim-20200910120006703.7z \
		"" \
		dxp-8-7210,hotfix-2824-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-2824-7210.zip

	build_bundle_image \
		7.2.10-dxp-9 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-9/liferay-dxp-tomcat-7.2.10-dxp-9-slim-20201208192626082.7z \
		"" \
		dxp-9-7210,hotfix-3661-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-3661-7210.zip

	build_bundle_image \
		7.2.10-dxp-10 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-10/liferay-dxp-tomcat-7.2.10-dxp-10-slim-20210112204850440.7z \
		"" \
		dxp-10-7210,hotfix-3971-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-3971-7210.zip

	build_bundle_image \
		7.2.10-dxp-11,7.2.10-sp4 \
		files.liferay.com/private/ee/portal/7.2.10.4/liferay-dxp-tomcat-7.2.10.4-sp4-slim-20210302130725158.7z \
		"" \
		dxp-11-7210,hotfix-4327-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-4327-7210.zip

	build_bundle_image \
		7.2.10-dxp-12 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-12/liferay-dxp-tomcat-7.2.10-dxp-12-slim-20210402105245543.7z \
		"" \
		dxp-12-7210,hotfix-4498-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-4498-7210.zip

	build_bundle_image \
		7.2.10-dxp-13 \
		files.liferay.com/private/ee/portal/7.2.10-dxp-13/liferay-dxp-tomcat-7.2.10-dxp-13-slim-20210511104400086.7z \
		"" \
		dxp-13-7210,hotfix-4803-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-4803-7210.zip

	build_bundle_image \
		7.2.10-dxp-14,7.2.10-sp5 \
		files.liferay.com/private/ee/portal/7.2.10.5/liferay-dxp-tomcat-7.2.10.5-sp5-slim-20210716110942552.7z \
		"" \
		dxp-14-7210,hotfix-5317-7210 \
		files.liferay.com/private/ee/fix-packs/7.2.10/hotfix/liferay-hotfix-5317-7210.zip
}

function build_bundle_images_dxp_73 {
	build_bundle_image \
		7.3.10-ga1 \
		files.liferay.com/private/ee/portal/7.3.10/liferay-dxp-tomcat-7.3.10-ga1-20200930160533946.7z \
		"" \
		hotfix-234-7310 \
		files.liferay.com/private/ee/fix-packs/7.3.10/hotfix/liferay-hotfix-234-7310.zip

	build_bundle_image \
		7.3.10-dxp-1 \
		files.liferay.com/private/ee/portal/7.3.10.1/liferay-dxp-tomcat-7.3.10.1-sp1-slim-20210303153956119.7z \
		"" \
		dxp-1-7310,hotfix-699-7310 \
		files.liferay.com/private/ee/fix-packs/7.3.10/hotfix/liferay-hotfix-699-7310.zip

	build_bundle_image \
		7.3.10-dxp-2 \
		files.liferay.com/private/ee/portal/7.3.10-dxp-2/liferay-dxp-tomcat-7.3.10-dxp-2-slim-20210623003016661.7z \
		"" \
		dxp-2-7310,hotfix-1736-7310 \
		files.liferay.com/private/ee/fix-packs/7.3.10/hotfix/liferay-hotfix-1736-7310.zip
}

function build_bundle_images_dxp_74 {
	build_bundle_image \
		7.4.12-ep3 \
		files.liferay.com/private/ee/portal/7.4.12/liferay-dxp-tomcat-7.4.12-ep3-20210728022041024.7z

	build_bundle_image \
		7.4.13-ep4-nightly \
		files.liferay.com/private/ee/portal/nightly/liferay-dxp-tomcat-7.4.10.7z
}

function main {
	if [ "${BUILD_ALL_IMAGES_PUSH}" == "push" ] && ! ./release_notes.sh fail-on-change
	then
		exit 1
	fi

	LOGS_DIR=logs-$(date "$(date)" "+%Y%m%d%H%M")

	mkdir -p "${LOGS_DIR}"

	build_base_image

	local release_file_urls=(
		#releases.liferay.com/commerce/2.0.7/liferay-commerce-2.0.7-7.2.x-201912261227.7z
		#files.liferay.com/private/ee/commerce/2.1.2/liferay-commerce-enterprise-2.1.2-7.1.x-202007312031.7z
		#files.liferay.com/private/ee/commerce/2.1.2/liferay-commerce-enterprise-2.1.2-7.2.x-202007312039.7z
		releases.liferay.com/portal/6.1.2-ga3/liferay-portal-tomcat-6.1.2-ce-ga3-20130816114619181.zip
		files.liferay.com/private/ee/portal/6.1.30.5/liferay-portal-tomcat-6.1-ee-ga3-sp5-20160201142343123.zip
		releases.liferay.com/portal/6.2.5-ga6/liferay-portal-tomcat-6.2-ce-ga6-20160112152609836.zip
		files.liferay.com/private/ee/portal/6.2.10.21/liferay-portal-tomcat-6.2-ee-sp20-20170717160924965.zip
		releases.liferay.com/portal/7.0.6-ga7/liferay-ce-portal-tomcat-7.0-ga7-20180507111753223.zip
		releases.liferay.com/portal/7.1.3-ga4/liferay-ce-portal-tomcat-7.1.3-ga4-20190508171117552.7z
		releases.liferay.com/portal/7.2.1-ga2/liferay-ce-portal-tomcat-7.2.1-ga2-20191111141448326.7z
		releases.liferay.com/portal/7.3.7-ga8/liferay-ce-portal-tomcat-7.3.7-ga8-20210610183559721.7z
		releases.liferay.com/portal/7.4.2-ga3/liferay-ce-portal-tomcat-7.4.2-ga3-20210728053338694.7z
		#releases.liferay.com/portal/snapshot-7.1.x/201902130905/liferay-portal-tomcat-7.1.x.7z
		releases.liferay.com/portal/snapshot-master/latest/liferay-portal-tomcat-master.7z
		#files.liferay.com/private/ee/portal/snapshot-ee-6.2.x/201808160944/liferay-portal-tomcat-ee-6.2.x.zip
		#files.liferay.com/private/ee/portal/snapshot-7.1.x-private/201808162051/liferay-portal-tomcat-7.1.x-private.zip
	)

	for release_file_url in "${release_file_urls[@]}"
	do
		build_bundle_image "" "${release_file_url}" "" ""
	done

	build_bundle_images_dxp_70
	build_bundle_images_dxp_71
	build_bundle_images_dxp_72
	build_bundle_images_dxp_73
	build_bundle_images_dxp_74

	echo ""
	echo "Results: "
	echo ""

	cat "${LOGS_DIR}/results"
}

main