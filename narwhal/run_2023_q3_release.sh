#!/bin/bash

# shellcheck disable=SC2086,SC2068
./run_release_builder.sh \
	-e LIFERAY_COMMON_DEBUG_ENABLED=1 \
	-e NARWHAL_GIT_SHA=7.4.13-u92 \
	${@}