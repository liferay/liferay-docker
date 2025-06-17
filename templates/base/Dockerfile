FROM --platform=${TARGETPLATFORM} ubuntu:plucky AS ubuntu-plucky

COPY resources/ /

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes bash ca-certificates curl jq less libnss3 telnet tini tree unzip && \
	apt-get upgrade --yes && \
	apt-get clean

RUN userdel ubuntu && \
	useradd --create-home --home-dir /home/liferay --shell /usr/sbin/nologin --uid 1000 --user-group liferay

FROM ubuntu-plucky

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG TARGETPLATFORM

ENV LANG="C.UTF-8"

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"