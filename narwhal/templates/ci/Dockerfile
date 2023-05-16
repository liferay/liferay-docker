FROM liferay/jdk11-jdk8

CMD ["bash"]

COPY resources/usr/local/sbin/ /usr/local/sbin/

ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_VERSION=zulu11
ENV TZ=Etc/UTC

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/sbin/jenkins.sh"]

RUN curl -fsSL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.11/jenkins-plugin-manager-2.12.11.jar -o /opt/jenkins-plugin-manager.jar

RUN curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key > /usr/share/keyrings/jenkins-keyring.asc && \
	echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list && \
	apt-get update && \
	apt-get install --no-install-recommends -y fontconfig git jenkins tini && \
	mkdir -p /var/cache/jenkins/war && \
	chown -R jenkins:jenkins /var/cache/jenkins && \
	apt-get upgrade -y && \
	apt-get clean && \
	update-java-alternatives -s zulu-11-amd64

USER jenkins