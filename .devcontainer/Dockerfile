ARG VARIANT="jammy"

FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get --yes install p7zip-full time

RUN wget https://github.com/mikefarah/yq/releases/download/v4.25.1/yq_linux_amd64 -O /usr/bin/yq && \
	chmod +x /usr/bin/yq