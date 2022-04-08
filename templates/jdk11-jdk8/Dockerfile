FROM --platform=${TARGETPLATFORM} liferay/jdk11:latest

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG LABEL_ZULU_8_VERSION
ARG TARGETARCH
ARG TARGETPLATFORM

ENV JAVA_VERSION=zulu8

RUN curl -L -s -H 'accept: */*' -X 'GET' -o /tmp/jdk8.deb "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?arch=${TARGETARCH}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=8.0&os=linux&zulu_version=$LABEL_ZULU_8_VERSION" && \
	apt-get install -y /tmp/jdk8.deb && \
	rm /tmp/jdk8.deb && \
	/usr/local/bin/set_java_version.sh 

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"
LABEL org.label-schema.zulu8_version="${LABEL_ZULU_8_VERSION}"