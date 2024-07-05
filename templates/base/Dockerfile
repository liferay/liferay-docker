FROM --platform=${TARGETPLATFORM} ubuntu:noble AS ubuntu-noble

COPY resources/etc/created-date /etc/created-date

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes bash build-essential ca-certificates curl jq less libnghttp2-dev libnss3 libssl-dev nghttp2 telnet tini tree unzip && \
	apt-get upgrade --yes && \
	apt-get clean

RUN userdel ubuntu && \
	useradd --create-home --home-dir /home/liferay --shell /usr/sbin/nologin --uid 1000 --user-group liferay

# Fix https://ubuntu.com/security/CVE-2024-2398
#
# START
RUN VERSION=8.7.1 && \
	curl https://curl.se/download/curl-${VERSION}.tar.gz --output curl-${VERSION}.tar.gz && \
	tar -vxzf curl-${VERSION}.tar.gz && \
	rm -f curl-${VERSION}.tar.gz && \
	cd curl-${VERSION} && \
	apt-get remove curl --yes && \
	rm -fr /usr/bin/curl* && \
	./configure --enable-static --prefix=/usr/local --with-nghttp2 --with-ssl && \
	make -j4 && \
	make install && \
	ldconfig && \
	cd .. && \
	rm -fr curl-${VERSION} && \
	apt-get remove build-essential libnghttp2-dev libssl-dev nghttp2 --yes
# END

FROM ubuntu-noble

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