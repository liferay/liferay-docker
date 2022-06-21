FROM zsoltbalogh/managed-dxp-dxp:latest

USER 0

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY resources/opt/liferay /opt/liferay/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/

RUN chown -R liferay:liferay /opt/liferay/deploy

USER liferay