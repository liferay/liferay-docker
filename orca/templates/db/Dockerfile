#FROM bitnami/mariadb-galera:10.5
FROM bitnami/mariadb-galera@sha256:cd63ec64f535e1a7554316429d2597cef94a60a0e877740e21a323c81afd2d4c

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
