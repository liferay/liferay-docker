FROM public.ecr.aws/gravitational/teleport:12

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC

COPY resources/etc/teleport/teleport.yaml /etc/teleport/
COPY resources/root/ /root/
COPY resources/usr/local/bin/ /usr/local/bin/

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/teleport_server_entrypoint.sh"]

RUN apt update && \
	apt upgrade -y && \
	apt clean && \
	rm -fr /var/lib/apt/lists/*