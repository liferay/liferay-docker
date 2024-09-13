#!/bin/bash

echo "Updating Ubuntu."
apt-get update
apt-get upgrade --yes
apt-get clean