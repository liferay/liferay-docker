#FROM elasticsearch:7.17.3
FROM elasticsearch@sha256:7167ec15528cca7e968736c73290506082305ee72e5ecb54ec0af2700326a34e

RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install \
	analysis-icu \
	analysis-kuromoji \
	analysis-smartcn \
	analysis-stempel
