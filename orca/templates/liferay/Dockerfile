#FROM liferay/dxp:7.4.13-u69-d5.0.19-20230322143344
FROM liferay/dxp@sha256:cb01f23843fc4bb66285778795eb0dce1c7a8fb468668c1c3b0fb370c06174e1

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