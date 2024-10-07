<?xml version="1.0"?>

<project
	xmlns="http://maven.apache.org/POM/4.0.0"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd"
>
	<modelVersion>4.0.0</modelVersion>
	<groupId>com.liferay.portal</groupId>
	<artifactId>__ARTIFACT_ID__</artifactId>
	<version>__ARTIFACT_RC_VERSION__</version>
	<packaging>pom</packaging>
	<licenses>
	  <license>
		<name>LGPL 2.1</name>
		<url>http://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt</url>
	  </license>
	</licenses>
	<developers>
		<developer>
			<name>Brian Wing Shun Chan</name>
			<organization>Liferay, Inc.</organization>
			<organizationUrl>http://www.liferay.com</organizationUrl>
		</developer>
	</developers>
	<scm>
		<connection>scm:git:git@github.com:liferay/__GITHUB_REPOSITORY__.git</connection>
		<developerConnection>scm:git:git@github.com:liferay/__GITHUB_REPOSITORY__.git</developerConnection>
		<tag>__PRODUCT_VERSION__</tag>
		<url>https://github.com/liferay/__GITHUB_REPOSITORY__</url>
	</scm>
	<repositories>
		<repository>
			<id>liferay-public-releases</id>
			<name>Liferay Public Releases</name>
			<url>https://repository-cdn.liferay.com/nexus/content/repositories/liferay-public-releases/</url>
		</repository>
	</repositories>
	<dependencyManagement>
		<dependencies>