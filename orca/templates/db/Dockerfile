FROM bitnami/mariadb-galera:10.4

USER 0
RUN apt-get update && apt-get install -y curl
USER 1001

COPY resources/usr/local/bin /usr/local/bin/

ENTRYPOINT [ "/usr/local/bin/liferay_entrypoint.sh" ]

CMD [ "/opt/bitnami/scripts/mariadb-galera/run.sh" ]