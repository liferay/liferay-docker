#!/bin/bash

function generate_liferay_conf {
	function write {
		echo "${1}" >> "/etc/apache2/sites-available/liferay.conf"
	}

	rm -f "/etc/apache2/sites-available/liferay.conf"

	write "<VirtualHost *:80>"
	write "    CustomLog /proc/self/fd/1 vhost_combined"
	write "    DocumentRoot /var/www/html"
	write "    ErrorLog /proc/self/fd/2"
	write "    ProxyPreserveHost On"
	write "    ProxyPass \"/\" \"balancer://cluster/\""
	write "    ServerAdmin webmaster@localhost"
	write ""
	write "    <Proxy \"balancer://cluster\">"

	for balance_member in ${ORCA_WEB_SERVER_BALANCE_MEMBERS//,/ }
	do
		local ajp_address="${balance_member##*::}"
		local route="${balance_member%%::*}"

		write "        BalancerMember \"ajp://${ajp_address}\" loadfactor=1 route=${route}"
	done

	write "        ProxySet stickysession=JSESSIONID"
	write "    </Proxy>"
	write "</VirtualHost>"

	echo "Generated /etc/apache2/sites-available/liferay.conf:"
	echo ""

	cat /etc/apache2/sites-available/liferay.conf
}

function main {
	generate_liferay_conf

	set_up_sites

	start_apache2
}

function set_up_sites {
	a2dissite "000-default.conf"
	a2ensite "liferay.conf"
}

function start_apache2 {
	mkdir /var/run/apache2

	chown www-data:www-data /var/run/apache2

	# shellcheck disable=SC1091
	source /etc/apache2/envvars

	/usr/sbin/apache2 -DFOREGROUND
}

main
