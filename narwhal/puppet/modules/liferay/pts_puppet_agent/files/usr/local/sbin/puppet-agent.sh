#!/bin/bash

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/opt/puppetlabs/bin'

host_server=$(grep ^server /etc/puppetlabs/puppet/puppet.conf | uniq | tr -d ' ' | cut -f2 -d'=')

timestamp_local_file='/var/tmp/puppet_timestamp.txt'
if [ -f "$timestamp_local_file" ];
  then
    timestamp_last=$(cat $timestamp_local_file)
  else
    # 2000-01-01
    timestamp_last='946681200'
fi

# can be enabled if timestamp.txt is served from the puppet server
# exit silently if the server is unavailable, otherwise it will spam with a bunch of emails our mailbox
#timestamp_remote=$(curl "$host_server:8000/timestamp.txt") || exit 0

# if the code version of the last successful run differs from the one downloaded on the server, then run puppet agent
#if ! [ "$timestamp_last" -eq "$timestamp_remote" ];
#  then
    puppet agent -t --detailed-exitcodes --color=false >/dev/null 2>&1 ;
#fi
err="$?"

# if the puppet agent returns with success (no change or successful changes) save the timestamp and save the version of the code
if [[ "$err" -eq 0 || "$err" -eq 2 ]];
  then
    date "+%s" | tee /var/tmp/puppet_last_run.txt > /dev/null
    echo "$timestamp_remote" | tee "$timestamp_local_file" > /dev/null
fi

# if the return code is suspicious that there was an error (repo update) on the server, run it again
if [[ "$err" -eq 4 ]];
  then
    if ! [ "$timestamp_last" -eq "$timestamp_remote" ];
      then
        puppet agent -t --detailed-exitcodes --color=false >/dev/null 2>&1 ;
    fi
    err="$?"
    if [[ "$err" -eq 0 || "$err" -eq 2 ]];
      then
        date "+%s" | tee /var/tmp/puppet_last_run.txt > /dev/null
        echo "$timestamp_remote" | tee "$timestamp_local_file" > /dev/null
    fi
fi
