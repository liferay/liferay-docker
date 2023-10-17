#!/bin/bash

function main {
	if [ ! -n "${LIFERAY_ROUTES_DXP}" ]
	then
		LIFERAY_ROUTES_DXP="/etc/liferay/lxc/dxp-metadata"
	fi

	local protocol=$(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.server.protocol 2>/dev/null)

	for i in $(cat ${LIFERAY_ROUTES_DXP}/com.liferay.lxc.dxp.domains 2>/dev/null)
	do
		local url="${protocol}://${i}"

		cat >> /etc/caddy.d/liferay_caddy_file << EOF
@origin${url} header Origin ${url}
header @origin${url} Access-Control-Allow-Origin "${url}"
header @origin${url} Vary Origin
EOF
	done

	if [ -n "${LIFERAY_CADDY_404_URL}" ]
	then
		cat >> /etc/caddy.d/liferay_caddy_file << EOF
handle_errors {

	@404 expression {http.error.status_code} == 404
	handle @404 {
		redir * ${LIFERAY_CADDY_404_URL} 301
	}

}
EOF
	fi

	caddy run --adapter caddyfile --config /etc/caddy/Caddyfile
}

main