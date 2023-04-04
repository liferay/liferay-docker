#!/bin/bash

set -o errexit
set -o pipefail

main() {
  echo "[DXP Cloud] Setup and start Nginx"


  echo -e "[DXP Cloud] Default nginx.conf\n"
  cat $SERVICE_HOME_DIR/nginx.conf
  echo -e "\n"

  process-public-directory.sh

  replace-environment-variables.sh

  mapfile -t PIDS < <(pgrep -u nginx)

  for PID in "${PIDS[@]}"; do
    echo "[DXP Cloud] Killing orphaned NGINX worker: ${PID}"
    kill -9 "$PID"
    while kill -0 "$PID" 2>/dev/null; do sleep 1; done
  done

  exec /usr/sbin/nginx -g 'daemon off;'
}

main "$@"
