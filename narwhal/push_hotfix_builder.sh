#!/bin/bash

cd templates/hotfix-builder

docker build . -t zsoltbalogh/hotfix-builder
docker push zsoltbalogh/hotfix-builder