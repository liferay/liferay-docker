#FROM liferay/base:4.1.0-20220613095221
FROM liferay/base@sha256:69216037cf0ba5e1b1aeca38c2c038713ec29bf3d824e5ad7a0debc0a822dceb

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get --yes install apache2 && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

RUN a2enmod proxy_ajp && \
	a2enmod proxy_balancer && \
	a2enmod lbmethod_byrequests

COPY resources/usr/local/bin /usr/local/bin/

ENTRYPOINT ["tini", "--", "/usr/local/bin/web_server_entrypoint.sh"]
