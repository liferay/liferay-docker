FROM liferay/jdk21:latest

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

CMD ["sleep", "infinity"]

COPY resources/ /

ENV LANG="C.UTF-8"

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"

RUN apt-get update && \
	\
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes ant git nano && \
	\
	apt-get upgrade --yes && \
	\
	apt-get clean

RUN useradd --create-home --shell /usr/bin/bash me && \
	\
	chown --recursive me:me /home/me && \
	\
	echo -n ". ~/.bashrc.liferay" >> /home/me/.bashrc && \
	\
	echo -n "set tabsize 4" > /home/me/.nanorc

USER me:me

WORKDIR /home/me