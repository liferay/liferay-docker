FROM liferay/dxp:7.4.13-u31-d4.1.4-20220629111505

USER 0

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY --chown=liferay:liferay resources/opt/liferay /opt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/

USER liferay

RUN /usr/local/bin/install_patch_on_build.sh