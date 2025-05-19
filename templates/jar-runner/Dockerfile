FROM --platform=${TARGETPLATFORM} liferay/jdk21-jdk11-jdk8:latest AS liferay-jdk21-jdk11-jdk8

COPY resources/etc/created-date /etc/created-date

FROM liferay-jdk21-jdk11-jdk8

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG TARGETPLATFORM

COPY resources/ /

ENTRYPOINT ["tini", "-v", "--", "/usr/local/bin/liferay_jar_runner_entrypoint.sh"]

ENV JAVA_VERSION=zulu21
ENV JDK_JAVA_OPTIONS="--add-opens=java.base/java.lang=ALL-UNNAMED \
	--add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
	--add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
	--add-opens=java.base/java.net=ALL-UNNAMED \
	--add-opens=java.base/sun.net.www.protocol.http=ALL-UNNAMED \
	--add-opens=java.base/sun.net.www.protocol.https=ALL-UNNAMED \
	--add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
	--add-opens=jdk.zipfs/jdk.nio.zipfs=ALL-UNNAMED"
ENV LANG="C.UTF-8"
ENV LIFERAY_JAR_RUNNER_JAVA_OPTS="-Xmx512m"

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

USER liferay:liferay

WORKDIR /opt/liferay