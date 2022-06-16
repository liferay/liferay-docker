#!bin/bash
source /etc/apache2/envvars

mkdir /var/run/apache2
chown www-data:www-data /var/run/apache2

echo "<VirtualHost *:80>" > /etc/apache2/sites-available/liferay.conf
echo "    ServerAdmin webmaster@localhost" >> /etc/apache2/sites-available/liferay.conf
echo "    DocumentRoot /var/www/html" >> /etc/apache2/sites-available/liferay.conf
echo "" >> /etc/apache2/sites-available/liferay.conf
echo "    <Proxy \"balancer://cluster\">" >> /etc/apache2/sites-available/liferay.conf

export IFS=","
for balance_member in ${LIFERAY_BALANCE_MEMBERS}
do
	echo "        BalancerMember \"ajp://${balance_member}\" loadfactor=1" >> /etc/apache2/sites-available/liferay.conf
done

echo "    </Proxy>" >> /etc/apache2/sites-available/liferay.conf
echo "    ProxyPass \"/\" \"balancer://cluster/\"" >> /etc/apache2/sites-available/liferay.conf
echo "</VirtualHost>" >> /etc/apache2/sites-available/liferay.conf

echo "Generated liferay site configuration: "
cat /etc/apache2/sites-available/liferay.conf

a2dissite 000-default.conf
a2ensite liferay.conf

/usr/sbin/apache2 -k start
tail -f /var/log/apache2/error.log