FROM liferay/jdk11-jdk8:5.0.9-20230124135117

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes ant git ssh p7zip-full zip && \
	apt-get upgrade --yes && \
	apt-get clean

ENTRYPOINT ["tini", "--", "/usr/local/bin/liferay_release_builder_entrypoint.sh"]

ENV ANT_OPTS="-Xmx10G"
ENV NARWHAL_BUILD_ID=1
ENV NARWHAL_GIT_SHA=7.2.x
ENV NARWHAL_OUTPUT=release
ENV NARWHAL_REMOTE=liferay

COPY resources/usr/local/bin/* /usr/local/bin/