#
# See https://github.com/zabbix/zabbix-docker/blob/6.2/Dockerfiles/web-nginx-mysql/ubuntu/Dockerfile
#

FROM zabbix/zabbix-web-nginx-mysql:ubuntu-latest as zabbix-web-nginx-mysql

FROM --platform=${TARGETPLATFORM} liferay/base:latest

ARG TARGETARCH
ARG TARGETPLATFORM
ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG LABEL_ZABBIX_VERSION

COPY --from=zabbix-web-nginx-mysql ["/etc/apt/preferences.d/99nginx", "/etc/apt/preferences.d/99nginx"]
COPY --from=zabbix-web-nginx-mysql ["/etc/apt/sources.list.d/nginx.list", "/etc/apt/sources.list.d/nginx.list"]
COPY --from=zabbix-web-nginx-mysql ["/etc/apt/trusted.gpg.d/nginx.gpg", "/etc/apt/trusted.gpg.d/nginx.gpg"]
COPY --from=zabbix-web-nginx-mysql ["/etc/nginx", "/etc/nginx"]
COPY --from=zabbix-web-nginx-mysql ["/etc/php", "/etc/php"]
COPY --from=zabbix-web-nginx-mysql ["/etc/supervisor", "/etc/supervisor"]
COPY --from=zabbix-web-nginx-mysql ["/etc/zabbix", "/etc/zabbix"]
COPY --from=zabbix-web-nginx-mysql ["/usr/bin/docker-entrypoint.sh", "/usr/bin/docker-entrypoint.sh"]
COPY --from=zabbix-web-nginx-mysql ["/usr/share/zabbix", "/usr/share/zabbix"]
COPY --from=zabbix-web-nginx-mysql ["/var/lib/locales/supported.d", "/var/lib/locales/supported.d"]
COPY --from=zabbix-web-nginx-mysql ["/var/lib/php/session", "/var/lib/php/session"]
COPY resources/etc/created-date /etc/created-date

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/bin/docker-entrypoint.sh"]

ENV TERM=xterm

EXPOSE 8080/TCP 8443/TCP

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"
LABEL org.label-schema.zabbix-version="${LABEL_ZABBIX_VERSION}"

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" bash ca-certificates curl libldap-common locales mysql-client nginx php8.1-bcmath php8.1-fpm php8.1-gd php8.1-ldap php8.1-mbstring php8.1-mysql php8.1-xml supervisor && \
	apt-get upgrade --yes && \
	apt-get clean

RUN groupadd --gid 1995 --system zabbix && \
	useradd -G root -g zabbix --home-dir /var/lib/zabbix/ --shell /sbin/nologin --system --uid 1997 zabbix

RUN ln -fs /dev/fd/2 /var/log/nginx/error.log && \
	rm -f /etc/nginx/conf.d/*.conf && \
	rm -f /etc/php/8.1/fpm/php-fpm.conf.dpkg-dist && \
	rm -f /etc/php/8.1/fpm/pool.d/www.conf && \
	rm -fr /var/cache/nginx && \
	dpkg-reconfigure locales

RUN	chown --quiet -R zabbix:root /etc/nginx /etc/php/8.1/fpm/php-fpm.conf /etc/php/8.1/fpm/pool.d && \
	chgrp -R 0 /etc/nginx /etc/php/8.1/fpm/php-fpm.conf /etc/php/8.1/fpm/pool.d && \
	chmod -R g=u /etc/nginx /etc/php/8.1/fpm/php-fpm.conf /etc/php/8.1/fpm/pool.d && \
	\
	chown --quiet -R zabbix:root /etc/zabbix /usr/share/zabbix/include/defines.inc.php /usr/share/zabbix/modules && \
	chgrp -R 0 /etc/zabbix /usr/share/zabbix/include/defines.inc.php /usr/share/zabbix/modules && \
	chmod -R g=u /etc/zabbix /usr/share/zabbix/include/defines.inc.php /usr/share/zabbix/modules && \
	\
	chown --quiet -R zabbix:root /var/lib/php/session && \
	chgrp -R 0 /var/lib/php/session && \
	chmod -R g=u /var/lib/php/session

STOPSIGNAL SIGTERM

USER 1997

WORKDIR /usr/share/zabbix