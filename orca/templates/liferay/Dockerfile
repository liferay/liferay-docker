#FROM liferay/dxp:2023.q3.1-d5.0.52-20231031145025
FROM liferay/dxp@sha256:a3bb5bb08892d282c904f4ad828296c2e24973917a4566ee21582468b30553d4

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