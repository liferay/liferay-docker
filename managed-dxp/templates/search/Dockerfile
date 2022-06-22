FROM elasticsearch:7.17.3

#COPY resources/usr/local/bin /usr/local/bin/

RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-icu analysis-kuromoji analysis-smartcn analysis-stempel

#ENTRYPOINT /usr/local/bin/search_entrypoint.sh