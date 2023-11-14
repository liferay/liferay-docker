#!/bin/bash

# shellcheck source=env.servers
source env.servers

find server-* -type f -exec sed -i \
		-e "s/__SERVER_1__/${__SERVER_1__}/" \
		-e "s/__SERVER_2__/${__SERVER_2__}/" \
		-e "s/__SERVER_3__/${__SERVER_3__}/" \
		-e "s/__SERVER_4__/${__SERVER_4__}/" \
		{} \;
