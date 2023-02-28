FROM liferay/jdk11-jdk8

COPY resources/usr/local/bin/ /usr/local/bin/

RUN curl -fsSL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.11/jenkins-plugin-manager-2.12.11.jar -o /opt/jenkins-plugin-manager.jar

RUN curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key > /usr/share/keyrings/jenkins-keyring.asc && \
	echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list && \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes fontconfig jenkins && \
	apt-get upgrade --yes && \
	apt-get clean && \
	update-java-alternatives -s zulu-11-amd64

ENV JAVA_VERSION=zulu11