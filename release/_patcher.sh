#!/bin/bash

function report_jenkins_url {
	if [ -z "${LIFERAY_RELEASE_HOTFIX_BUILD_ID}" ] ||
	   [ -z "${LIFERAY_RELEASE_PATCHER_REQUEST_KEY}" ]
	then
		echo "LIFERAY_RELEASE_HOTFIX_BUILD_ID, LIFERAY_RELEASE_PATCHER_REQUEST_KEY are not set."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir -p "${_BUILD_DIR}"/patcher-status/production/osbPatcherStatus/build/jenkins

	lc_cd "${_BUILD_DIR}"/patcher-status/production/osbPatcherStatus/build/jenkins

	(
		echo "{"
		echo "    \"patcherRequestKey\":\"${LIFERAY_RELEASE_PATCHER_REQUEST_KEY}\""
		echo "    \"status\":\"pending\","
		echo "    \"statusURL\":\"${BUILD_URL}\","
		echo "}"
	) > "${LIFERAY_RELEASE_HOTFIX_BUILD_ID}"

	rsync -rlptDvz --chown=501:501 --no-perms "${_BUILD_DIR}"/patcher-status/ test-3-1::patcher/
}