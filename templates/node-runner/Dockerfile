FROM node:16-alpine

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

COPY resources/usr/local/bin/* /usr/local/bin/

ENV LIFERAY_NODE_RUNNER_START="echo Started..."

ENTRYPOINT ["/usr/local/bin/liferay_node_runner_entrypoint.sh"]

EXPOSE 3000

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN mkdir /opt/node

WORKDIR /opt/node
