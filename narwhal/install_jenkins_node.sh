#!/bin/bash

apt-get update
apt-get --yes install docker docker.io jq openjdk-11-jdk p7zip-full
snap install yq

adduser jenkins
usermod -a -G docker jenkins
mkdir -p /home/jenkins/.ssh
echo "${JENKINS_SSH_PUB_KEY}" > /home/jenkins/.ssh/authorized_keys
chown -R jenkins:jenkins /home/jenkins/.ssh