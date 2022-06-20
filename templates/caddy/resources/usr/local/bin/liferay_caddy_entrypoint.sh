function main {
	for i in $(echo ${LIFERAY_CADDY_CORS_ALLOWED_ORIGIN} | tr "," "\n")
	do
		local address="https://${i}"

		cat >> /etc/caddy.d/cors.txt << EOF
@origin${address} header Origin ${address}
header @origin${address} Access-Control-Allow-Origin "${address}"
header @origin${address} Vary Origin
EOF
	done

	caddy run --adapter caddyfile --config /etc/caddy/Caddyfile
}

main