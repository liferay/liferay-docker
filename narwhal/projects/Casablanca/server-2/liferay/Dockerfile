#FROM liferay/dxp:2023.q3.2
FROM liferay/dxp@sha256:d56c597df45b9fabf90e60b7cfe7d39b3df82e90f8c61d4e131ef2ce168858bd

USER 0

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean

COPY --chown=liferay:liferay resources/opt/liferay /opt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/

HEALTHCHECK --retries=3 \
	CMD /usr/local/bin/probe_thread_dump.sh -d "http://localhost" -f "/c/portal/robots" -p 8080 -t 20

USER liferay

RUN /usr/local/bin/install_patch_on_build.sh
