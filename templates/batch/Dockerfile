FROM liferay/base:latest

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

COPY resources/etc/created-date /etc/created-date
COPY resources/usr/local/bin/* /usr/local/bin/

ENTRYPOINT ["tini", "-v", "--", "/usr/local/bin/liferay_batch_entrypoint.sh"]

ENV LANG="C.UTF-8"

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

USER liferay:liferay

WORKDIR /opt/liferay