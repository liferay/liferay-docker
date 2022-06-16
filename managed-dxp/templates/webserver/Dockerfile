FROM liferay/base:4.1.0-20220613095221

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get --yes install apache2 && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* && \
	a2enmod proxy_ajp

COPY scripts /usr/local/bin

ENTRYPOINT ["tini", "--", "/usr/local/bin/webserver_entrypoint.sh"]