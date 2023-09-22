FROM --platform=linux/arm64 liferay/base:latest as liferay-base-arm64

ARG LABEL_NODE_RUNNER_AMD64_VERSION
ARG LABEL_NODE_RUNNER_ARM64_VERSION
ARG LABEL_NODE_RUNNER_VERSION=${LABEL_NODE_RUNNER_ARM64_VERSION}

FROM --platform=linux/amd64 liferay/base:latest as liferay-base-amd64

ARG LABEL_NODE_RUNNER_AMD64_VERSION
ARG LABEL_NODE_RUNNER_ARM64_VERSION
ARG LABEL_NODE_RUNNER_VERSION=${LABEL_NODE_RUNNER_AMD64_VERSION}

FROM liferay-base-${TARGETARCH}

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG NODE_VERSION=16
ARG TARGETARCH
ARG TARGETPLATFORM

COPY resources/etc/created-date /etc/created-date
COPY resources/usr/local/bin/* /usr/local/bin/

ENTRYPOINT ["tini", "-v", "--", "/usr/local/bin/liferay_node_runner_entrypoint.sh"]

ENV LANG="C.UTF-8"
ENV LIFERAY_NODE_RUNNER_START="npm start"

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.node_version="${NODE_VERSION}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN apt-get update && \
	apt-get upgrade --yes && \
	apt-get clean && \
	apt-get install --yes gnupg && \
	mkdir -p /etc/apt/keyrings && \
	curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
	echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
	apt-get update && \
	apt-get install --yes nodejs

USER liferay:liferay

WORKDIR /opt/liferay