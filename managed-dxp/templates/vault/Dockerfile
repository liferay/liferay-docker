FROM liferay/base:latest

RUN apt-get update && \
	apt-get --yes install gnupg lsb-release && \
	curl https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
	apt-get update && \
	apt-get install vault

ENTRYPOINT ["vault", "server", "-dev"]