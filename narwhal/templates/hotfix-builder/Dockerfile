FROM liferay/jdk11-jdk8:5.0.9-20230124135117

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes ant git ssh zip && \
	apt-get upgrade --yes && \
	apt-get clean

ENTRYPOINT ["tini", "--", "/usr/local/bin/liferay_hotfix_builder_entrypoint.sh"]

ENV ANT_OPTS="-Xmx10G"

COPY resources/usr/local/bin/* /usr/local/bin/

USER liferay