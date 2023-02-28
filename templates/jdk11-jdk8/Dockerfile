FROM --platform=linux/amd64 liferay/jdk11:latest as liferay-jdk11-amd64

ARG LABEL_ZULU_8_AMD64_VERSION
ARG LABEL_ZULU_8_ARM64_VERSION
ARG LABEL_ZULU_8_VERSION=${LABEL_ZULU_8_AMD64_VERSION}

FROM --platform=linux/arm64 liferay/jdk11:latest as liferay-jdk11-arm64

ARG LABEL_ZULU_8_AMD64_VERSION
ARG LABEL_ZULU_8_ARM64_VERSION
ARG LABEL_ZULU_8_VERSION=${LABEL_ZULU_8_ARM64_VERSION}

FROM liferay-jdk11-${TARGETARCH}

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG LABEL_ZULU_8_VERSION
ARG TARGETARCH
ARG TARGETPLATFORM

COPY resources/etc/created-date /etc/created-date

ENV JAVA_VERSION=zulu8

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"
LABEL org.label-schema.zulu8_amd64_version="${LABEL_ZULU_8_AMD64_VERSION}"
LABEL org.label-schema.zulu8_arm64_version="${LABEL_ZULU_8_ARM64_VERSION}"
LABEL org.label-schema.zulu8_version="${LABEL_ZULU_8_VERSION}"

RUN curl -H 'accept: */*' -L -s -X 'GET' -o /tmp/jdk8.deb "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?arch=${TARGETARCH}&bundle_type=jdk&ext=deb&hw_bitness=64&java_version=8.0&javafx=false&os=linux&zulu_version=${LABEL_ZULU_8_VERSION}" && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes /tmp/jdk8.deb && \
	rm /tmp/jdk8.deb && \
	/usr/local/bin/set_java_version.sh