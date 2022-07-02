FROM liferay/job-runner:4.1.4-20220629112801

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

COPY resources/mnt/liferay /mnt/liferay/
COPY resources/usr/local/bin /usr/local/bin/

ENTRYPOINT ["tini", "-v", "--", "/usr/local/bin/liferay_backup_entrypoint.sh"]