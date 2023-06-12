#!/bin/bash

set -e

main() {
  setup_haproxy
}

setup_haproxy() {
  exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
}

echo "[DXP Cloud] Setup and start HAProxy"
main "$@"