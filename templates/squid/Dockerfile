FROM debian:bullseye-slim

COPY resources/usr/local/bin/* /usr/local/bin/

ENTRYPOINT ["tini", "-v", "--", "/usr/local/bin/liferay_squid_entrypoint.sh"]

EXPOSE 3128 4128

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN apt-get update && \
	apt-get install --yes openssl squid-openssl tini

COPY resources/etc/squid/squid.conf /etc/squid/squid.conf