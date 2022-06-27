function main {
	local domains_file=/etc/liferay/lxc/dxp-metadata/com.liferay.lxc.dxp.domains

	if [ -f $domains_file ]
	then
		for i in $(cat $domains_file)
		do
			local url="https://${i}"

			cat >> /etc/caddy.d/liferay_caddy_file << EOF
@origin${url} header Origin ${url}
header @origin${url} Access-Control-Allow-Origin "${url}"
header @origin${url} Vary Origin
EOF
		done
	fi

	caddy run --adapter caddyfile --config /etc/caddy/Caddyfile
}

main