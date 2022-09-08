FROM liferay/job-runner:5.0.0-20220830072327

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

COPY resources/mnt/liferay /mnt/liferay/
COPY resources/usr/local/bin /usr/local/bin/