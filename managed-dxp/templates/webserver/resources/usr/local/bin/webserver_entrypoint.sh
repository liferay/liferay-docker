#!bin/bash

function add_conf_line {
	echo "${1}" >> /etc/apache2/sites-available/liferay.conf
}

function generate_liferay_conf {
	add_conf_line "<VirtualHost *:80>"
	add_conf_line "    ServerAdmin webmaster@localhost"
	add_conf_line "    DocumentRoot /var/www/html"
	add_conf_line ""
	add_conf_line "    <Proxy \"balancer://cluster\">"

	export IFS=","
	for balance_member in ${LIFERAY_BALANCE_MEMBERS}
	do
		local route=${balance_member%%::*}
		local host_port=${balance_member##*::}
		add_conf_line "        BalancerMember \"ajp://${host_port}\" route=${route} loadfactor=1"
	done
	add_conf_line "        ProxySet stickysession=JSESSIONID"
	add_conf_line "    </Proxy>"
	add_conf_line "    ProxyPreserveHost On"
	add_conf_line "    ProxyPass \"/\" \"balancer://cluster/\""
	add_conf_line "</VirtualHost>"

	echo "Generated liferay site configuration: "
	cat /etc/apache2/sites-available/liferay.conf
}

function main {
	generate_liferay_conf

	setup_sites

	start_apache2
}

function setup_sites {
	a2dissite 000-default.conf
	a2ensite liferay.conf
}

function start_apache2 {
	source /etc/apache2/envvars
	mkdir /var/run/apache2
	chown www-data:www-data /var/run/apache2

	/usr/sbin/apache2 -k start

	tail -f /var/log/apache2/error.log
}

main