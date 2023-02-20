FROM liferay/jdk11-jdk8

RUN curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io.key > /usr/share/keyrings/jenkins-keyring.asc && \
	echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list && \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes fontconfig jenkins && \
	apt-get upgrade --yes && \
	apt-get clean && \
	update-java-alternatives -s zulu-11-amd64

ENV JAVA_VERSION=zulu11