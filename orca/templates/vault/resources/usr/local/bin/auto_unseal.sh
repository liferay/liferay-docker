#!/bin/bash

source /usr/local/bin/_common.sh

wait_for_operator "\"standby\":true"

vault operator unseal "$(cat /opt/liferay/vault/data/unseal_key)"
