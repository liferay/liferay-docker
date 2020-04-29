FROM azul/zulu-openjdk-alpine:8u232

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

RUN apk --no-cache add bash curl nss tomcat-native tree ttf-dejavu zulu11-jdk=11.0.5-r3

COPY scripts/* /usr/local/bin/

RUN adduser -D -h /home/liferay liferay && addgroup liferay liferay

COPY --chown=liferay:liferay home/.bashrc /home/liferay/
COPY --chown=liferay:liferay liferay /opt/liferay

ENTRYPOINT /usr/local/bin/liferay_entrypoint.sh

ENV JAVA_VERSION=zulu8
ENV JPDA_ADDRESS=8000

ENV LIFERAY_HOME=/opt/liferay
ENV LIFERAY_JPDA_ENABLED=false
ENV LIFERAY_JVM_OPTS=
ENV LIFERAY_PRODUCT_NAME="${LABEL_NAME}"

ENV LIFERAY_MODULE_PERIOD_FRAMEWORK_PERIOD_PROPERTIES_PERIOD_OSGI_PERIOD_CONSOLE=0.0.0.0:11311
ENV LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ADD_PERIOD_SAMPLE_PERIOD_DATA=false
ENV LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ENABLED=false
ENV LIFERAY_TERMS_PERIOD_OF_PERIOD_USE_PERIOD_REQUIRED=false
ENV LIFERAY_USERS_PERIOD_REMINDER_PERIOD_QUERIES_PERIOD_ENABLED=false

EXPOSE 8000 8009 8080 11311

HEALTHCHECK \
	--interval=1m \
	--start-period=1m \
	--timeout=1m \
	CMD curl -fsS "http://localhost:8080/c/portal/layout" || exit 1

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

USER liferay:liferay

WORKDIR /opt/liferay