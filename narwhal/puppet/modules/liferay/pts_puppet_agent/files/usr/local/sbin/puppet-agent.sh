#!/bin/bash

PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/opt/puppetlabs/bin'

host_server=$(grep ^server /etc/puppetlabs/puppet/puppet.conf | uniq | tr -d ' ' | cut -f2 -d'=')

timestamp_local_file='/var/tmp/puppet_timestamp.txt'

if [ -f "${timestamp_local_file}" ]
then
	timestamp_last=$(cat ${timestamp_local_file})
else
	timestamp_last=$(date -d 2000-01-01 "+%s")
fi

# The following can be enabled if timestamp.txt is served from the puppet server, eg. via http.
# It is planned to be implemented in the close future.

# Exit silently if the server is unavailable, otherwise it will spam with a bunch of emails our mailbox.

#timestamp_remote=$(curl "$host_server:8000/timestamp.txt") || exit 0

# If the version of the last successful running differs from the one downloaded from the server, then puppet agent should run

#if ! [ "$timestamp_last" -eq "$timestamp_remote" ]
#	then
		puppet agent -t --detailed-exitcodes --color=false >/dev/null 2>&1
#fi

return_code="${?}"

# if the puppet agent return_codeurns with success (no change or successful changes) save the timestamp and save the version of the code
if [[ "${return_code}" -eq 0 || "${return_code}" -eq 2 ]]
	then
		date "+%s" | tee /var/tmp/puppet_last_run.txt > /dev/null
		#echo "${timestamp_remote}" | tee "${timestamp_local_file}" > /dev/null
fi

# If the return_codeurn code is suspicious that there was an error (most probably an intermittent repo update job was running) on the server.
# Run it again.

if [[ "${return_code}" -eq 4 ]]
then
	#if ! [ "${timestamp_last}" -eq "${timestamp_remote}" ]
	#	then
			puppet agent -t --detailed-exitcodes --color=false >/dev/null 2>&1 ;
	#fi

	return_code="${?}"

	if [[ "${return_code}" -eq 0 || "${return_code}" -eq 2 ]]
	then
			date "+%s" | tee /var/tmp/puppet_last_run.txt > /dev/null
			#echo "$timestamp_remote" | tee "$timestamp_local_file" > /dev/null
	fi
fi
