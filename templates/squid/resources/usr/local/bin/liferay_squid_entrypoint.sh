#!/bin/bash

function main {
	rm --force /run/squid.pid

	if [ ! -e /etc/squid/seeder.crt ]
	then
		mkdir --parents /var/lib/squid

		/usr/lib/squid/security_file_certgen \
			-c \
			-s /var/lib/squid/ssl_db \
			-M 20MB

		chown --recursive proxy:proxy /var/lib/squid

		openssl req \
			-days 365 \
			-keyout /etc/squid/seeder.key \
			-new \
			-newkey rsa:2048 \
			-nodes \
			-out /etc/squid/seeder.crt \
			-subj /C=US/ST=CA/L=LAX/O=Liferay/OU=IT/CN=localhost \
			-x509
	fi

	squid -z && rm --force /run/squid.pid

	squid -CNYd 1

	#
	# curl --location https://dlcdn.apache.org/netbeans/netbeans/19/netbeans-19-bin.zip --output netbeans-19-bin.zip --preproxy localhost:3129
	# curl --location https://www.bbc.com/robots.txt --preproxy localhost:3129
	#
}

main