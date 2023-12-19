#
# See https://github.com/zabbix/zabbix-docker/blob/6.2/Dockerfiles/server-mysql/ubuntu/Dockerfile
#

FROM zabbix/zabbix-server-mysql:ubuntu-latest as zabbix-server-mysql

FROM --platform=${TARGETPLATFORM} liferay/base:latest

ARG TARGETARCH
ARG TARGETPLATFORM
ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG LABEL_ZABBIX_VERSION

CMD ["/usr/sbin/zabbix_server", "--foreground", "-c", "/etc/zabbix/zabbix_server.conf"]

COPY --from=zabbix-server-mysql ["/etc/zabbix", "/etc/zabbix"]
COPY --from=zabbix-server-mysql ["/usr/bin/docker-entrypoint.sh", "/usr/bin/docker-entrypoint.sh"]
COPY --from=zabbix-server-mysql ["/usr/bin/zabbix_get", "/usr/bin/zabbix_get"]
COPY --from=zabbix-server-mysql ["/usr/bin/zabbix_sender", "/usr/bin/zabbix_sender"]
COPY --from=zabbix-server-mysql ["/usr/lib/zabbix", "/usr/lib/zabbix"]
COPY --from=zabbix-server-mysql ["/usr/sbin/zabbix_server", "/usr/sbin/zabbix_server"]
COPY --from=zabbix-server-mysql ["/usr/share/doc/zabbix-server-mysql", "/usr/share/doc/zabbix-server-mysql"]
COPY --from=zabbix-server-mysql ["/var/lib/zabbix", "/var/lib/zabbix"]
COPY resources/etc/created-date /etc/created-date

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/docker-entrypoint.sh"]

ENV MIBDIRS=/var/lib/mibs/ietf:/var/lib/mibs/iana:/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL
ENV TERM=xterm

EXPOSE 10051/TCP

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"
LABEL org.label-schema.zabbix-version="${LABEL_ZABBIX_VERSION}"

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes fping iputils-ping libevent-2.1 libcurl4 libmysqlclient21 libopenipmi0 libpcre2-8-0 libsnmp40 libssh-4 libssl3 libxml2 mysql-client nmap snmp-mibs-downloader traceroute tzdata unixodbc && \
	apt-get upgrade --yes && \
	apt-get clean

RUN groupadd --gid 1995 --system zabbix && \
	useradd -G root,dialout -g zabbix --home-dir /var/lib/zabbix/ --shell /sbin/nologin --system --uid 1997 zabbix

RUN chown --quiet -R zabbix:root /etc/zabbix /var/lib/zabbix && \
	chgrp -R 0 /etc/zabbix /var/lib/zabbix && \
	chmod -R g=u /etc/zabbix /var/lib/zabbix && \
	rm -fr /var/lib/apt/lists/*

STOPSIGNAL SIGTERM

USER 1997

VOLUME ["/var/lib/zabbix/snmptraps", "/var/lib/zabbix/export"]

WORKDIR /var/lib/zabbix