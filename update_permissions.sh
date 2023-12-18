#!/bin/bash

find . -name "*.sh" ! -name "_*.sh" -type f -exec chmod 744 {} ";"

find . -name "_*.sh" -type f -exec chmod 644 {} ";"