#!/bin/bash

function lc_time_run_error {
	report_patcher_status &>/dev/null
}

function report_jenkins_url {
	if [ -z "${LIFERAY_RELEASE_HOTFIX_BUILD_ID}" ] ||
	   [ -z "${LIFERAY_RELEASE_PATCHER_REQUEST_KEY}" ]
	then
		echo "Set the environment variables LIFERAY_RELEASE_HOTFIX_BUILD_ID and LIFERAY_RELEASE_PATCHER_REQUEST_KEY."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	mkdir -p "${_BUILD_DIR}"/patcher-status/production/osbPatcherStatus/build/jenkins

	lc_cd "${_BUILD_DIR}"/patcher-status/production/osbPatcherStatus/build/jenkins

	(
		echo "{"
		echo "    \"patcherRequestKey\": \"${LIFERAY_RELEASE_PATCHER_REQUEST_KEY}\","
		echo "    \"status\": \"pending\","
		echo "    \"statusURL\": \"${BUILD_URL}\""
		echo "}"
	) > "${LIFERAY_RELEASE_HOTFIX_BUILD_ID}"

	rsync -Dlprtvz --chown=501:501 --no-perms "${_BUILD_DIR}"/patcher-status/ test-3-1::patcher/
}

function report_patcher_status {
	lc_cd "${_BUILD_DIR}"/patcher-status/production/osbPatcherStatus/build/jenkins

	(
		echo "{"

		if [ -n "${LC_TIME_RUN_ERROR_EXIT_CODE}" ]
		then
			echo "    \"exitValue\": ${LC_TIME_RUN_ERROR_EXIT_CODE},"
			echo "    \"output\": \"Problem during ${LC_TIME_RUN_ERROR_FUNCTION}.\","
		else
			echo "    \"exitValue\": 0,"
			echo "    \"fileName\": \"${_DXP_VERSION}/${_HOTFIX_FILE_NAME}\","
		fi

		echo "    \"patcherRequestKey\": \"${LIFERAY_RELEASE_PATCHER_REQUEST_KEY}\","
		echo "    \"patcherUserId\": ${LIFERAY_RELEASE_PATCHER_USER_ID}"
		echo "}"
	) > "${LIFERAY_RELEASE_HOTFIX_BUILD_ID}"

	cat "${LIFERAY_RELEASE_HOTFIX_BUILD_ID}"

	rsync -Dlprtvz --chown=501:501 --no-perms "${_BUILD_DIR}"/patcher-status/ test-3-1::patcher/
}