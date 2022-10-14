FROM liferay/dxp:7.4.13-u45-d5.0.1-20221006125539

USER 0

RUN apt-get update && \
	apt-get --yes install mariadb-client && \
	apt-get upgrade --yes && \
	apt-get clean && \
	rm -fr /var/lib/apt/lists/*

RUN curl -H 'accept: */*' -L -s -X 'GET' -o /tmp/zabbix_agent.deb https://repo.zabbix.com/zabbix/6.3/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.3-1%2Bubuntu22.04_all.deb && \
	dpkg -i /tmp/zabbix_agent.deb && \
	rm -rf /tmp/zabbix_agent.deb && \
	apt update && \
	apt-get upgrade --yes  && \
	apt install zabbix-agent2  && \
	apt-get clean

COPY --chown=liferay:liferay resources/opt/liferay /opt/liferay/
COPY resources/usr/local/bin /usr/local/bin/
COPY resources/usr/local/liferay/scripts /usr/local/liferay/scripts/
COPY resources/etc/zabbix/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf

RUN mkdir -p /etc/zabbix && \
	mkdir -p /etc/zabbix/zabbix_agentd.d && \
	mkdir -p /var/lib/zabbix && \
	mkdir -p /var/run/zabbix && \
	mkdir -p /var/lib/zabbix/enc && \
	mkdir -p /var/lib/zabbix/modules && \
	mkdir -p /var/lib/zabbix/buffer && \
	mkdir -p /var/log/zabbix/ && \
	touch /var/log/zabbix/zabbix_agent2.log && \
	chown --quiet -R liferay:liferay /etc/zabbix/ /var/lib/zabbix/ /var/run/zabbix/ && \
	chgrp -R 0 /etc/zabbix/ /var/lib/zabbix/ /var/run/zabbix/ && \
	chmod -R g=u /etc/zabbix/ /var/lib/zabbix/ /var/run/zabbix/

USER liferay

RUN /usr/local/bin/install_patch_on_build.sh