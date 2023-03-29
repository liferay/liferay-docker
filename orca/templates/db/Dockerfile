FROM ubuntu:jammy

# original source: https://github.com/percona/percona-docker/blob/master/percona-server-8.0/Dockerfile

ENV PS_VERSION 8.0.32-24
ENV OS_VER jammy
ENV FULL_PERCONA_VERSION "$PS_VERSION.$OS_VER"
ENV DEBIAN_FRONTEND noninteractive
ENV TZ Etc/UTC

RUN groupadd -g 1001 mysql && \
	useradd -u 1001 -g 1001 -s /bin/false -d /var/lib/mysql mysql

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

RUN install -m 0775 -o mysql -g root -d /var/lib/mysql /var/run/mysqld && \
	install -m 0775 -o root -g root -d /docker-entrypoint-initdb.d && \
	echo "$TZ" > /etc/localtime && dpkg-reconfigure tzdata && \
	find /etc/mysql/conf.d/ /etc/mysql/mysql.cnf /etc/mysql/mysql.conf.d/ -name '*.cnf' -print0 \
		| xargs -0 grep -lZE '^(bind-address|log|user)' \
		| xargs -rt -0 sed -Ei 's/^(bind-address|log|user)/#&/'; \
	# don't reverse lookup hostnames, they are usually another container
	echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/mysql.conf.d/docker.cnf

#COPY resources/docker-entrypoint.sh /docker-entrypoint.sh
COPY resources/usr/local/bin/ /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/liferay_entrypoint.sh"]

USER mysql
CMD ["mysqld"]
