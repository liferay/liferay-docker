#!/bin/bash

echo "[DXP Cloud] Starting Webserver Service."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf -n
