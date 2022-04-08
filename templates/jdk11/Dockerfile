FROM --platform=${TARGETPLATFORM} liferay/base:latest

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG LABEL_ZULU_11_VERSION
ARG TARGETARCH
ARG TARGETPLATFORM

ENV JAVA_VERSION=zulu11

COPY --chown=liferay:liferay home/.bashrc /home/liferay/
COPY --chown=liferay:liferay scripts/set_java_version.sh /usr/local/bin/ 

RUN apt-get update && \
	apt-get install -y jattach && \
	apt-get upgrade -y && \
	apt-get clean && \
	curl -L -s -H 'accept: */*' -X 'GET' -o /tmp/jdk11.deb "https://api.azul.com/zulu/download/community/v1.0/bundles/latest/binary/?arch=${TARGETARCH}&bundle_type=jdk&ext=deb&hw_bitness=64&javafx=false&java_version=11.0&os=linux&zulu_version=$LABEL_ZULU_11_VERSION" && \
	apt-get install -y /tmp/jdk11.deb && \
	rm /tmp/jdk11.deb && \
	/usr/local/bin/set_java_version.sh 

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"
LABEL org.label-schema.zulu11_version="${LABEL_ZULU_11_VERSION}"