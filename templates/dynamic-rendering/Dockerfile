FROM liferay/base

ARG LABEL_BUILD_DATE
ARG LABEL_PRERENDER_VERSION
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION
ARG TARGETARCH
ARG TARGETPLATFORM

ENV MEMORY_CACHE=0
ENV NODE_VERSION=node16

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
	curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
	sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
		>> /etc/apt/sources.list.d/google.list' && \
	apt-get update && \
	apt-get upgrade -y && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y nodejs google-chrome-stable && \
	apt-get clean

WORKDIR /usr/src/app

COPY . /usr/src/app

RUN npm install --no-package-lock

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

USER liferay:liferay

ENTRYPOINT ["tini", "--", "node", "server.js"]
