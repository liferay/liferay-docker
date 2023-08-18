# FROM ubuntu:jammy-20230804
FROM ubuntu:jammy@sha256:56887c5194fddd8db7e36ced1c16b3569d89f74c801dc8a5adbf48236fb34564 AS builder

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

# Production image
FROM ubuntu:jammy

COPY --from=builder /usr/local/bin/tang-show-keys /usr/local/bin/tang-show-keys
COPY --from=builder /usr/local/libexec/tangd /usr/local/bin/tangd
COPY --from=builder /usr/local/libexec/tangd-keygen /usr/local/bin/tangd-keygen
COPY --from=builder /usr/local/libexec/tangd-rotate-keys /usr/local/bin/tangd-rotate-keys
COPY healtcheck.sh /usr/local/bin/healtcheck.sh

ENTRYPOINT [ "tini", "-s", "-v", "-w", "--", "/usr/local/bin/tangd", "-l", "/db" ]

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
	rm -rf /var/cache/apt/archives /var/lib/apt/lists && \
	groupadd -g 1001 tang && \
	useradd -g 1001 -s /bin/false -u 1001 -d /db tang

USER tang
