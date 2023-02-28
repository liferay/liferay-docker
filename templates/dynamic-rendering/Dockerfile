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
COPY resources/usr/src/app/* /usr/src/app

ENV MEMORY_CACHE=0
ENV NODE_VERSION=node16

ENTRYPOINT ["tini", "--", "xvfb-run", "--server-args=-screen 0 1024x768x24", "node", "server.js"]

EXPOSE 3000

HEALTHCHECK \
	--interval=1m \
	--start-period=15s \
	--timeout=1m \
	CMD node ./lib/healthcheck.js || exit 1

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.job-runner-version="${LABEL_JOB_RUNNER_VERSION}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
	curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
	sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' && \
	apt-get update && \
	apt-get upgrade -y && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y nodejs google-chrome-stable xvfb && \
	apt-get clean && \
	\
	npm install --no-package-lock

USER liferay:liferay

WORKDIR /usr/src/app