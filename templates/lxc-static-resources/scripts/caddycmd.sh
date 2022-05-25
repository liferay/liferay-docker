for i in $(echo $CORS_ALLOWED_ORIGIN | tr "," "\n"); do
    ADDRESS="https://${i}" # strictly https
    cat >> /etc/caddy.d/cors.txt << EOF
    @origin${ADDRESS} header Origin ${ADDRESS}
    header @origin${ADDRESS} Access-Control-Allow-Origin "${ADDRESS}"
    header @origin${ADDRESS} Vary Origin
EOF
done
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile