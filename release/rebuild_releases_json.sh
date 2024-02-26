#!/bin/bash

source _liferay_common.sh
source _releases_json.sh

_RELEASE_ROOT_DIR=$(pwd)

_PROMOTION_DIR="${_RELEASE_ROOT_DIR}/release-data/promotion/files"

rm -fr "${_PROMOTION_DIR}"

mkdir -p "${_PROMOTION_DIR}"

lc_cd "${_PROMOTION_DIR}"

regenerate_releases_json

upload_releases_json