FROM public.ecr.aws/gravitational/teleport:12

COPY resources/etc/teleport/teleport.yaml /etc/teleport/
COPY resources/root/ /root/
COPY resources/usr/local/bin/ /usr/local/bin/

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ENTRYPOINT ["/usr/bin/dumb-init", "--", "/usr/local/bin/teleport_server_entrypoint.sh"]

RUN apt update && \
	apt upgrade -y && \
	apt clean && \
	rm -fr /var/lib/apt/lists/*