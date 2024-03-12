#!/bin/bash

find . -name "*.sh" ! -name "_*.sh" -type f -exec chmod 755 {} ";"

find . -name "_*.sh" -type f -exec chmod 644 {} ";"