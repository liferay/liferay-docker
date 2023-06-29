#!/bin/bash

set -x

tini -s -v -w -- /usr/local/bin/tangd -l /db
