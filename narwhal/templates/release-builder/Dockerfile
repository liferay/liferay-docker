FROM liferay/jdk11-jdk8:5.0.9-20230124135117

RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install --no-install-recommends --yes ant apt-transport-https ca-certificates gnupg git ssh p7zip-full zip && \
	echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
	apt-get update && \
	apt-get install google-cloud-cli && \
	apt-get upgrade --yes && \
	apt-get clean


ENTRYPOINT ["tini", "--", "/usr/local/bin/liferay_release_builder_entrypoint.sh"]

ENV ANT_OPTS="-Xmx10G"

#
# The id of the hotfix
#

ENV NARWHAL_BUILD_ID=1

#
# The git tag or branch to check out from the liferay-portal-ee
#
ENV NARWHAL_GIT_SHA=7.2.x

#
# Either release or fix pack
#
ENV NARWHAL_OUTPUT=release

#
# The github username used to check out on the liferay-portal-ee repository. Should be used only for debugging purposes
#
ENV NARWHAL_REMOTE=liferay

#
# Tag name in the liferay-portal-ee repository which contains the hotfix testing SHA-s if you would like to build a test hotfix
#
ENV NARWHAL_HOTFIX_TESTING_TAG=

#
# Git SHA which would be cherry-picked on NARWHAL_GIT_SHA from the tree of NARWHAL_HOTFIX_TESTING_TAG to build a test hotfix
#
ENV NARWHAL_HOTFIX_TESTING_SHA=

#
# If this is set, the files will be uploaded to the designated buckets
#
ENV NARWHAL_UPLOAD=

#
# The name of the GCS bucket where the internal files should be copied
#
ENV NARWHAL_GCS_INTERNAL_BUCKET=patcher-storage


COPY resources/usr/local/bin/* /usr/local/bin/