#FROM liferay/job-runner:5.0.53-20231110013150
FROM liferay/job-runner@sha256:e6522b92f5628132a143b69eb21622552909a4da23d5d796df42d07bd63f63d2

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

COPY resources/mnt/liferay /mnt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
