#!/bin/bash

CA_PIN=$(tctl status | awk '/CA pin/{print $3}')
export CA_PIN

INVITE_TOKEN=$(tctl nodes add --ttl=5m --roles=node | grep "invite token:" | grep -Eo "[0-9a-z]{32}")
export INVITE_TOKEN

tctl tokens ls
export ADDR="10.111.111.10:3025"

echo "Join command on node:"
echo "teleport start --roles=node --token=${INVITE_TOKEN?} --ca-pin=${CA_PIN?} --auth-server=${ADDR?}"
