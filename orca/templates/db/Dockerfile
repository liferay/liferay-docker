FROM bitnami/mariadb-galera:10.4

USER 0

RUN apt-get update && \
	apt-get --yes install curl && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

USER 1001

COPY resources/usr/local/bin /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/liferay_entrypoint.sh" ]

CMD [ "/opt/bitnami/scripts/mariadb-galera/run.sh" ]