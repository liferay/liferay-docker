FROM openjdk:8u171-jdk-alpine3.8

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VERSION

COPY .bashrc /etc/liferay/
COPY entrypoint.sh /etc/liferay/
COPY liferay /opt/liferay

ENTRYPOINT /etc/liferay/entrypoint.sh

ENV LIFERAY_HOME=/opt/liferay
ENV LIFERAY_PRODUCT_NAME="${LABEL_NAME}"

EXPOSE 8080 11311

HEALTHCHECK \
	--interval=1m \
	--start-period=1m \
	--timeout=1m \
	CMD curl -fsS "http://localhost:8080/c/portal/layout" || exit 1

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="https://github.com/liferay/liferay-docker"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN adduser -D -h /etc/liferay liferay && addgroup liferay liferay && chown -R liferay:liferay /opt/liferay
RUN apk add bash tree

USER liferay:liferay

WORKDIR /opt/liferay