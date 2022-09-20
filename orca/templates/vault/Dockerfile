FROM liferay/base:latest

RUN apt-get update && \
	apt-get --yes install gnupg libcap2-bin lsb-release pwgen && \
	curl https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
	apt-get update && \
	apt-get install vault

# Workaround for https://github.com/hashicorp/vault/issues/10924
RUN setcap -r /usr/bin/vault

COPY resources/opt/liferay/vault /opt/liferay/vault
COPY resources/usr/local/bin /usr/local/bin


USER liferay

WORKDIR /opt/liferay/vault

ENV VAULT_ADDR='http://127.0.0.1:8200'

ENTRYPOINT ["vault", "server", "-config=config.hcl"]