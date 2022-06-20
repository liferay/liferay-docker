FROM liferay/dxp:7.4.13-u28-d4.1.2-snapshot-20220618053134

USER 0

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY resources/opt/liferay /opt/liferay/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/

USER liferay