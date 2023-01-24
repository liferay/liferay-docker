#FROM liferay/job-runner:5.0.0-20220830072327
FROM liferay/job-runner@sha256:1f77e45c00c325cca3b80d13fc3de0871b0e24a4024478b7a7296b5730f3c087

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

COPY resources/mnt/liferay /mnt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
