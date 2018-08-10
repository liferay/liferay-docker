FROM openjdk:8u171-jdk-alpine3.8

ARG LABEL_BUILD_DATE
ARG LABEL_NAME

COPY .bashrc /root
COPY liferay /liferay/home
COPY entrypoint.sh /liferay

ENTRYPOINT /liferay/entrypoint.sh

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
LABEL org.label-schema.vendor="Liferay, Inc."

RUN apk add bash tree

WORKDIR /liferay