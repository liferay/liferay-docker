FROM azul/zulu-openjdk-alpine:8u282

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

RUN apk --no-cache add bash curl ghostscript imagemagick nss tomcat-native tree ttf-dejavu zulu11-jdk=11.0.5-r3
RUN apk --no-cache upgrade

COPY scripts/* /usr/local/bin/

RUN adduser -D -h /home/liferay liferay && addgroup liferay liferay

COPY --chown=liferay:liferay home/.bashrc /home/liferay/

ENV JAVA_VERSION=zulu8

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"