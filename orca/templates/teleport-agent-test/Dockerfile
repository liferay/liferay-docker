FROM ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

RUN apt update && \
	apt upgrade -y && \
	apt install --no-install-recommends -y openssh-server curl ca-certificates

RUN curl https://apt.releases.teleport.dev/gpg -o /usr/share/keyrings/teleport-archive-keyring.asc && \
	echo "deb [signed-by=/usr/share/keyrings/teleport-archive-keyring.asc] https://apt.releases.teleport.dev/ubuntu jammy stable/v12" > /etc/apt/sources.list.d/teleport.list && \
	apt update && \
	apt install -y teleport && \
	apt clean && \
	rm -fr /var/lib/apt/lists/*

RUN adduser liferay --gecos "Liferay common user" --disabled-password && \
	install -d /home/liferay/.ssh/ -o liferay -g liferay -m 0700 && \
	echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9cRilRehhA3bBKZfd8OITMFVyzQBUvCjvbejLsJavD tamas.papp@liferay' > /home/liferay/.ssh/authorized_keys && \
	echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILOu945eSM8vlNkxMmnYrIYkoFaPO0L7+M0cWnV8/tH2 zsolt.balogh@liferay' >> /home/liferay/.ssh/authorized_keys && \
	chown -R liferay:liferay /home/liferay/ && \
	chmod 600 /home/liferay/.ssh/authorized_keys

CMD ["teleport","start","--roles=node","--token=/agent-test/token.txt","--auth-server=teleport-proxy"]