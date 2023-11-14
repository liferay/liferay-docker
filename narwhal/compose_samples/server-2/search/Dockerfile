FROM docker.elastic.co/elasticsearch/elasticsearch:7.17.14

RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install \
	analysis-icu \
	analysis-kuromoji \
	analysis-smartcn \
	analysis-stempel
