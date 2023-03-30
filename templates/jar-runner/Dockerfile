FROM --platform=${TARGETPLATFORM} liferay/jdk11:latest AS liferay-jdk11

FROM liferay-jdk11

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG TARGETPLATFORM

RUN \
	export ARCH=$(dpkg --print-architecture) && \
	curl -fsSL "https://dl.filippo.io/mkcert/latest?for=linux/${ARCH}" -o /usr/local/bin/mkcert && \
	chmod +x /usr/local/bin/mkcert && \
	mkdir /var/lib/caroot

COPY resources/opt/app/app.sh /opt/app/app.sh

ENV LANG C.UTF-8
ENV LIFERAY_JAR_RUNNER_DEBUG_PORT=8001
ENV LIFERAY_JAR_RUNNER_OPTS=-Xmx512m -agentlib:jdwp=transport=dt_socket,address=*:${LIFERAY_JAR_RUNNER_DEBUG_PORT},server=y,suspend=n

RUN chmod +x /opt/app/app.sh

ENTRYPOINT ["tini", "-v", "--", "/opt/app/app.sh"]

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

WORKDIR /opt/app