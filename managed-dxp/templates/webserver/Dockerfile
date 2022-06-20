FROM liferay/base:4.1.0-20220613095221

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get --yes install apache2 && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN a2enmod proxy_ajp && \
	a2enmod proxy_balancer && \
	a2enmod lbmethod_byrequests

COPY resources/usr/local/bin /usr/local/bin/

ENTRYPOINT ["tini", "--", "/usr/local/bin/webserver_entrypoint.sh"]