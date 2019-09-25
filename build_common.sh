#!/bin/bash

function check_utils {

	#
	# https://stackoverflow.com/a/677212
	#

	for util in "${@}"
	do
		command -v ${util} >/dev/null 2>&1 || { echo >&2 "The utility ${util} is not installed."; exit 1; }
	done
}

function configure_tomcat {
	printf "\nCATALINA_OPTS=\"\${CATALINA_OPTS} \${LIFERAY_JVM_OPTS}\"" >> ${1}/liferay/tomcat/bin/setenv.sh
}

function date {
	if [ -z ${1+x} ] || [ -z ${2+x} ]
	then
		if [ "$(uname)" == "Darwin" ]
		then
			echo $(/bin/date)
		elif [ -e /bin/date ]
		then
			echo $(/bin/date)
		else
			echo $(/usr/bin/date)
		fi
	else
		if [ "$(uname)" == "Darwin" ]
		then
			echo $(/bin/date -jf "%a %b %e %H:%M:%S %Z %Y" "${1}" "${2}")
		elif [ -e /bin/date ]
		then
			echo $(/bin/date -d "${1}" "${2}")
		else
			echo $(/usr/bin/date -d "${1}" "${2}")
		fi
	fi
}

function get_tomcat_version {
	if [ -e ${1}/tomcat-* ]
	then
		for temp_file_name in `ls ${1}`
		do
			if [[ ${temp_file_name} == tomcat-* ]]
			then
				local liferay_tomcat_version=${temp_file_name#*-}
			fi
		done
	fi

	if [ -z ${liferay_tomcat_version+x} ]
	then
		echo "Unable to determine Tomcat version."

		exit 1
	fi

	echo ${liferay_tomcat_version}
}

function start_tomcat {
	local temp_dir=${1}

	./${temp_dir}/liferay/tomcat/bin/catalina.sh start

	until $(curl --head --fail --output /dev/null --silent http://localhost:8080)
	do
		sleep 3
	done

	./${temp_dir}/liferay/tomcat/bin/catalina.sh stop

	sleep 10

	rm -fr ${temp_dir}/liferay/data/osgi/state
	rm -fr ${temp_dir}/liferay/osgi/state
	rm -fr ${temp_dir}/liferay/tomcat/logs/*
}

function stat {
	if [ "$(uname)" == "Darwin" ]
	then
		echo $(/usr/bin/stat -f "%z" "${1}")
	else
		echo $(/usr/bin/stat --printf="%s" "${1}")
	fi
}

function warm_up_tomcat {
	local temp_dir=${1}

	if [ -d ${temp_dir}/liferay/data/hsql ]
	then
		if [ $(stat ${temp_dir}/liferay/data/hsql/lportal.script) -lt 1024000 ]
		then
			start_tomcat ${temp_dir}
		else
			echo Tomcat is already warmed up.
		fi
	fi

	if [ -d ${temp_dir}/liferay/data/hypersonic ]
	then
		if [ $(stat ${temp_dir}/liferay/data/hypersonic/lportal.script) -lt 1024000 ]
		then
			start_tomcat ${temp_dir}
		else
			echo Tomcat is already warmed up.
		fi
	fi
}
