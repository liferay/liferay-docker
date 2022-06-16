#!bin/bash
source /etc/apache2/envvars

mkdir /var/run/apache2
chown www-data:www-data /var/run/apache2

/usr/sbin/apache2 -DFOREGROUND -k start