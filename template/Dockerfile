FROM azul/zulu-openjdk-alpine:8u212

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VERSION
ARG LIFERAY_TOMCAT_VERSION

COPY scripts/* /etc/liferay/

RUN adduser -D -h /etc/liferay liferay && addgroup liferay liferay

COPY --chown=liferay:liferay home/.bashrc /etc/liferay/
COPY --chown=liferay:liferay liferay /opt/liferay

ENTRYPOINT /etc/liferay/entrypoint.sh

ENV LIFERAY_HOME=/opt/liferay
ENV LIFERAY_JPDA_ENABLED=false
ENV LIFERAY_JVM_OPTS=
ENV LIFERAY_PRODUCT_NAME="${LABEL_NAME}"

ENV LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ADD_PERIOD_SAMPLE_PERIOD_DATA=false
ENV LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ENABLED=false
ENV LIFERAY_TERMS_PERIOD_OF_PERIOD_USE_PERIOD_REQUIRED=false
ENV LIFERAY_USERS_PERIOD_REMINDER_PERIOD_QUERIES_PERIOD_ENABLE=false

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

RUN apk add bash curl nss tomcat-native tree ttf-dejavu

USER liferay:liferay

RUN ln -s tomcat-${LIFERAY_TOMCAT_VERSION} /opt/liferay/tomcat

WORKDIR /opt/liferay