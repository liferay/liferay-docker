#!/bin/bash

/usr/bin/java \
	-Dhudson.lifecycle=hudson.lifecycle.ExitLifecycle \
	-Duser.home=/var/lib/jenkins \
	-jar /usr/share/java/jenkins.war \
	--httpPort=8080 \
	--webroot=/var/cache/jenkins/war
