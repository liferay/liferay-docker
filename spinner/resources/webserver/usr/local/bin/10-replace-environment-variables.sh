#!/bin/bash

check_and_export_default() {
  if [[ -z ${!1} ]]; then
    echo "[DXP Cloud] Setting ${1}=${2}"
    export ${1}="${2}"
  else
    echo "[DXP Cloud] Using ${1}=${!1}"
  fi
}

main() {
  echo "[SRE-2782] replacing environment variables in *.conf files"

  export LCP_WEBSERVER_PROXY_CONNECT_TIMEOUT="75s"
  check_and_export_default LCP_WEBSERVER_PROXY_READ_TIMEOUT "5m"
  check_and_export_default LCP_WEBSERVER_PROXY_SEND_TIMEOUT "5m"

  export ENVSUBST_ARGS="
    \${LCP_WEBSERVER_PROXY_CONNECT_TIMEOUT},
    \${LCP_WEBSERVER_PROXY_READ_TIMEOUT},
    \${LCP_WEBSERVER_PROXY_SEND_TIMEOUT}"

  find "${SERVICE_HOME_DIR}" -name "*.conf" -exec bash -c 'envsubst "${ENVSUBST_ARGS}" < $1 | sponge $1' _ {} \;
}

main