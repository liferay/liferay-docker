FROM ubuntu:jammy AS builder

ARG TANG_COMMIT_SHA=100265e32f56e33c8120fca83de419155ac8db5e

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt-get update && \
	apt-get install --no-install-recommends -y \
		ca-certificates \
		curl \
		gcc \
		gcovr \
		git \
		iproute2 \
		jose \
		libhttp-parser-dev \
		libhttp-parser2.9 \
		libjose-dev \
		meson \
		pkg-config \
		socat \
		systemd

RUN git clone https://github.com/latchset/tang.git && \
	cd tang && \
	git checkout ${TANG_COMMIT_SHA} && \
	mkdir build && \
	cd build && \
	meson .. --prefix=/usr/local && \
	ninja install

#
# PRODUCTION IMAGE DEFINITION
#

FROM ubuntu:jammy

COPY --from=builder /usr/local/bin/tang-show-keys /usr/local/bin/tang-show-keys
COPY --from=builder /usr/local/libexec/tangd /usr/local/bin/tangd
COPY --from=builder /usr/local/libexec/tangd-keygen /usr/local/bin/tangd-keygen
COPY --from=builder /usr/local/libexec/tangd-rotate-keys /usr/local/bin/tangd-rotate-keys
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healtcheck.sh /usr/local/bin/healtcheck.sh

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

HEALTHCHECK --start-period=5s \
			--timeout=3s \
			CMD "healtcheck.sh"

RUN apt-get update && \
	apt-get -y --no-install-recommends install \
		curl \
		jose \
		libhttp-parser2.9 \
		openssl \
		python3-http-parser \
		socat \
		tini \
		wget && \
	rm -rf /var/cache/apt/archives /var/lib/apt/lists
