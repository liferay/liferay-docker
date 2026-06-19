FROM liferay/base:latest

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG NODE_VERSION_22=22.23.0
ARG NODE_VERSION_24=24.17.0
ARG TARGETARCH
ARG TARGETPLATFORM

COPY resources/ /

ENTRYPOINT ["tini", "-v", "--", "/usr/local/bin/liferay_node_runner_entrypoint.sh"]

ENV LANG="C.UTF-8"
ENV LIFERAY_NODE_RUNNER_START="npm start"
ENV NODE_VERSION="v22"

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.node_version_22="${NODE_VERSION_22}"
LABEL org.label-schema.node_version_24="${NODE_VERSION_24}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN apt-get update && \
	apt-get upgrade --yes && \
	apt-get clean && \
	/usr/local/bin/install_node.sh "${NODE_VERSION_22}" /usr/local/node/v22 && \
	/usr/local/bin/install_node.sh "${NODE_VERSION_24}" /usr/local/node/v24

USER liferay:liferay

WORKDIR /opt/liferay