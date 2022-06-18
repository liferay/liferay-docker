FROM liferay/dxp:7.2.10-dxp-18-d4.1.1-snapshot-20220617040326

USER 0

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY scripts /usr/local/liferay/scripts

USER liferay