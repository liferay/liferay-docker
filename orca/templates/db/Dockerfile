# ubuntu:jammy-20230308
FROM ubuntu:jammy@sha256:7a57c69fe1e9d5b97c5fe649849e79f2cfc3bf11d10bbd5218b4eb61716aebe6

# original source: https://github.com/percona/percona-docker/blob/master/percona-server-8.0/Dockerfile

ENV DEBIAN_FRONTEND noninteractive
ENV PS_VERSION 8.0.32-24
ENV TZ Etc/UTC

RUN groupadd -g 1001 mysql && \
	useradd -d /var/lib/mysql -g 1001 -s /bin/false -u 1001 mysql

RUN set -ex; \
	apt-get update && \
	apt-get install --no-install-recommends -y ca-certificates curl tzdata && \
	curl -L https://github.com/percona/percona-repositories/raw/main/deb/percona-keyring.gpg -o /etc/apt/trusted.gpg.d/percona.gpg && \
	echo "deb http://repo.percona.com/ps-80/apt jammy main" > /etc/apt/sources.list.d/percona-ps-80.list && \
	echo "deb http://repo.percona.com/tools/apt jammy main" > /etc/apt/sources.list.d/percona-tools.list && \
	apt-get update && \
	apt-get install --no-install-recommends -y percona-server-server && \
	rm -rf /var/cache/apt /var/lib/apt && \
	rm -rf /var/lib/mysql

RUN install -d /var/lib/mysql /var/run/mysqld -g root -m 0700 -o mysql && \
	echo "$TZ" > /etc/localtime && dpkg-reconfigure tzdata && \
	find /etc/mysql/conf.d/ /etc/mysql/mysql.cnf /etc/mysql/mysql.conf.d/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user)/#&/'

COPY resources/etc/mysql/mysql.conf.d/ /etc/mysql/mysql.conf.d/
COPY resources/usr/local/bin/ /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/liferay_entrypoint.sh"]

USER mysql
CMD ["mysqld"]
