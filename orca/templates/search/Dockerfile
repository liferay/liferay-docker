#FROM elasticsearch:7.17.9
FROM elasticsearch@sha256:56789f44fd8c451fdeb40a095c5089367e588c7a24e0a03cdbd6ba53ebd84649

RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install \
	analysis-icu \
	analysis-kuromoji \
	analysis-smartcn \
	analysis-stempel