FROM liferay/base:latest

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_PRERENDER_VERSION
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG TARGETARCH
ARG TARGETPLATFORM

COPY resources/etc/created-date /etc/created-date
COPY resources/usr/local/bin/* /usr/local/bin/

SHELL ["/bin/bash", "-c"]

ENTRYPOINT /usr/local/bin/liferay_batch_entrypoint.sh

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.job-runner-version="${LABEL_JOB_RUNNER_VERSION}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN apt-get update && \
	apt-get upgrade -y && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y jq && \
	apt-get clean && \
	mkdir -p /batch

USER liferay:liferay

WORKDIR /batch