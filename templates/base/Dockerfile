FROM azul/zulu-openjdk:8u302

ARG LABEL_BUILD_DATE
ARG LABEL_NAME
ARG LABEL_VCS_REF
ARG LABEL_VCS_URL
ARG LABEL_VERSION

RUN apt update && \
  apt install -y bash curl ffmpeg ghostscript gifsicle imagemagick libnss3 libtcnative-1 tree ttf-dejavu zulu11-jdk=11.0.12-1 && \
  apt upgrade -y && \
  apt clean

COPY scripts/* /usr/local/bin/

RUN adduser --disabled-password --home /home/liferay liferay --uid 1000 && \
  addgroup liferay liferay && \
  usermod -g 1000 liferay

COPY --chown=liferay:liferay home/.bashrc /home/liferay/

ENV JAVA_VERSION=zulu8

LABEL org.label-schema.build-date="${LABEL_BUILD_DATE}"
LABEL org.label-schema.name="${LABEL_NAME}"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.vcs-ref="${LABEL_VCS_REF}"
LABEL org.label-schema.vcs-url="${LABEL_VCS_URL}"
LABEL org.label-schema.vendor="Liferay, Inc."
LABEL org.label-schema.version="${LABEL_VERSION}"