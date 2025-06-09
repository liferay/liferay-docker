#!/bin/bash

source ./_publishing.sh

function prepare_jars_for_promotion {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ -n "${nexus_repository_name}" ] && ([ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" || -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}" ])
	then
		lc_log ERROR "Either \${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD} or \${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local nexus_repository_name="${1}"
	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	for jar_rc_name in "release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}.jar" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.api-${_ARTIFACT_RC_VERSION}-sources.jar" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.jar"
	do
		local jar_release_name="${jar_rc_name/-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}/}"

		if [ -n "${nexus_repository_name}" ]
		then
			_download_bom_file "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/$(echo ${jar_rc_name} | cut -d '-' -f 1)/${_ARTIFACT_RC_VERSION}/${jar_rc_name}" "${_PROMOTION_DIR}/${jar_release_name}"
		else
			mv "${_PROMOTION_DIR}/${jar_rc_name}" "${_PROMOTION_DIR}/${jar_release_name}"
			mv "${_PROMOTION_DIR}/${jar_rc_name}.MD5" "${_PROMOTION_DIR}/${jar_release_name}.MD5"
			mv "${_PROMOTION_DIR}/${jar_rc_name}.sha512" "${_PROMOTION_DIR}/${jar_release_name}.sha512"
		fi
	done

	if [ -n "${nexus_repository_name}" ]
	then
		_download_bom_file "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro/${_ARTIFACT_RC_VERSION}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_RC_VERSION}.jar" "${_PROMOTION_DIR}/release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro-${_ARTIFACT_VERSION}.jar"
	fi
}

function prepare_poms_for_promotion {
	trap 'return ${LIFERAY_COMMON_EXIT_CODE_BAD}' ERR

	if [ -n "${nexus_repository_name}" ] && ([ -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" || -z "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}" ])
	then
		lc_log ERROR "Either \${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD} or \${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER} is undefined."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

	local nexus_repository_name="${1}"
	local nexus_repository_url="https://repository.liferay.com/nexus/service/local/repositories"

	for pom_name in "release.${LIFERAY_RELEASE_PRODUCT_NAME}.api" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.compile.only" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.bom.third.party" "release.${LIFERAY_RELEASE_PRODUCT_NAME}.distro"
	do
		if [ -n "${nexus_repository_name}" ]
		then
			_download_bom_file "${nexus_repository_url}/${nexus_repository_name}/content/com/liferay/portal/${pom_name}/${_ARTIFACT_RC_VERSION}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom" "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_VERSION}.pom"
		else
			mv "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom" "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_VERSION}.pom"
			mv "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom.MD5" "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_VERSION}.pom.MD5"
			mv "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_RC_VERSION}.pom.sha512" "${_PROMOTION_DIR}/${pom_name}-${_ARTIFACT_VERSION}.pom.sha512"
		fi
	done

	sed -i "s#<version>${_ARTIFACT_RC_VERSION}</version>#<version>${_ARTIFACT_VERSION}</version>#" ./*.pom
}

function promote_boms {
	lc_time_run prepare_jars_for_promotion ${1}
	lc_time_run prepare_poms_for_promotion ${1}

	lc_time_run upload_boms liferay-public-releases
}

function promote_packages {
	ssh root@lrdcom-vm-1 "exit" &> /dev/null

	if [ "${?}" -eq 0 ]
	then
		if (ssh root@lrdcom-vm-1 ls -d "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}" | grep --quiet "${_PRODUCT_VERSION}" &>/dev/null)
		then
			lc_log INFO "Release was already published."

			return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
		fi

		ssh root@lrdcom-vm-1 cp -a "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/release-candidates/${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" "/www/releases.liferay.com/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}"
	fi

	if (gsutil ls "gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}" | grep "${_PRODUCT_VERSION}")
	then
		lc_log INFO "Skipping the upload of ${_PRODUCT_VERSION} to GCP because it already exists."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	gsutil cp -r "gs://liferay-releases-candidates/${_PRODUCT_VERSION}-${LIFERAY_RELEASE_RC_BUILD_TIMESTAMP}" "gs://liferay-releases/${LIFERAY_RELEASE_PRODUCT_NAME}/${_PRODUCT_VERSION}"
}

function _download_bom_file {
	local file_name="${2}"
	local file_url="${1}"

	_download_from_nexus "${file_url}" "${file_name}" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_download_from_nexus "${file_url}.md5" "${file_name}.MD5" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	_download_from_nexus "${file_url}.sha512" "${file_name}.sha512" || return "${LIFERAY_COMMON_EXIT_CODE_BAD}"

	_verify_checksum "${file_name}"
}

function _download_from_nexus {
	local file_url="${1}"
	local file_name="${2}"

	lc_log DEBUG "Downloading ${file_url} to ${file_name}."

	curl \
		--fail \
		--max-time 300 \
		--output "${file_name}" \
		--retry 3 \
		--retry-delay 10 \
		--silent \
		--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" \
		"${file_url}"

	if [ "${?}" -ne 0 ]
	then
		lc_log ERROR "Unable to download ${file_url} to ${file_name}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}

function _verify_checksum {
	file="${1}"

	(
		sed -z "s/\n$//" "${file}.sha512"

		echo "  ${file}"
	) | sha512sum -c - --status

	if [ "${?}" != "0" ]
	then
		lc_log ERROR "Unable to verify the checksum of ${file}."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi
}