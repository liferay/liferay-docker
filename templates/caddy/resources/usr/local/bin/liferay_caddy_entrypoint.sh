function main {
	for i in $(echo ${LIFERAY_CADDY_CORS_ALLOWED_ORIGIN} | tr "," "\n")
	do
		local url="https://${i}"

		cat >> /etc/caddy.d/cors.txt << EOF
@origin${url} header Origin ${url}
header @origin${url} Access-Control-Allow-Origin "${url}"
header @origin${url} Vary Origin
EOF
	done

	caddy run --adapter caddyfile --config /etc/caddy/Caddyfile
}

main