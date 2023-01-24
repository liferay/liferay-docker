#!/bin/bash

touch /tmp/build_nightly-${RANDOM}.txt
echo "${PATH}" > /tmp/build_nightly-${RANDOM}.txt
echo $(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)") > /tmp/build_nightly-${RANDOM}.txt

cd $(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")

LIFERAY_DOCKER_IMAGE_FILTER=7.4.13.nightly ./build_all_images.sh --push
