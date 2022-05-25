FROM caddy:2.5.0

ARG LABEL_BUILD_DATE
ARG LABEL_LXC_STATIC_RESOURCES_VERSION
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG TARGETPLATFORM

RUN mkdir -p /resources /etc/caddy.d

ENV ACCESS_CONTROL_ALLOW_METHODS="GET, POST, OPTIONS"
ENV ACCESS_CONTROL_ALLOW_HEADERS="*"

COPY scripts/caddycmd.sh /usr/share/caddycmd.sh
RUN chmod +x /usr/share/caddycmd.sh
COPY Caddyfile /etc/caddy/Caddyfile

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.lxc-static-resources-version="${LABEL_LXC_STATIC_RESOURCES_VERSION}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

CMD ["sh", "-c", "/usr/share/caddycmd.sh"]