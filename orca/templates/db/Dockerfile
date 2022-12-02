#Base image name: bitnami/mariadb-galera:10.4
FROM bitnami/mariadb-galera@sha256:45d7ca6c585eea7de4246f87d92057892f0fa93d6c9306e7082dd84865260af7

USER 0

RUN apt-get update && \
	apt-get --yes install curl && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

USER 1001

CMD [ "/opt/bitnami/scripts/mariadb-galera/run.sh" ]

COPY resources/usr/local/bin /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/liferay_entrypoint.sh" ]