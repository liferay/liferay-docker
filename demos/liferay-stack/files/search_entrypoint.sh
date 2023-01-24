#!/usr/bin/env bash
    
/usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-icu analysis-kuromoji analysis-smartcn analysis-stempel

exec /usr/local/bin/docker-entrypoint.sh elasticsearch
