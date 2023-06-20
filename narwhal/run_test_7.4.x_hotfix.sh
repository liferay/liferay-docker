#!/bin/bash

# shellcheck disable=SC2086,SC2068
./run_release_builder.sh -e LIFERAY_COMMON_DEBUG_ENABLED=1 -e NARWHAL_GIT_SHA=7.4.13-u81 -e NARWHAL_FIXED_ISSUES=LPS-1 -e NARWHAL_OUTPUT=hotfix -e NARWHAL_HOTFIX_TESTING_TAG=test-fix-pack-new-builder-7.4 -e NARWHAL_HOTFIX_TESTING_SHA=4e9a87e9bd09bb818061932eccfd0cbf9205f7e7 ${@}