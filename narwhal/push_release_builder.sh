#!/bin/bash

cd templates/hotfix-builder || exit 3

docker build . -t zsoltbalogh/hotfix-builder
docker push zsoltbalogh/hotfix-builder