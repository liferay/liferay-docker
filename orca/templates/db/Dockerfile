#FROM bitnami/mariadb-galera:10.4
FROM bitnami/mariadb-galera@sha256:19cb3929b2c2b08bd8240339da0fb193529349091b805370b6cf8be67c3e4fe1

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