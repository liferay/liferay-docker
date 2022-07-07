function main {
	for i in $(cat /etc/liferay/lxc/dxp-metadata/com.liferay.lxc.dxp.domains 2>/dev/null)
	do
		local url="https://${i}"

		cat >> /etc/caddy.d/liferay_caddy_file << EOF
@origin${url} header Origin ${url}
header @origin${url} Access-Control-Allow-Origin "${url}"
header @origin${url} Vary Origin
EOF

		if [ "${ALLOW_INSECURE}" == "true" ]
		then
			url="http://${i}"

			cat >> /etc/caddy.d/liferay_caddy_file << EOF
@origin${url} header Origin ${url}
header @origin${url} Access-Control-Allow-Origin "${url}"
header @origin${url} Vary Origin
EOF
		fi
	done

	caddy run --adapter caddyfile --config /etc/caddy/Caddyfile
}

main