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

function clean_up_temp_directory {
	rm -fr ${TEMP_DIR}
}

function configure_tomcat {
	printf "\nCATALINA_OPTS=\"\${CATALINA_OPTS} \${LIFERAY_JVM_OPTS}\"" >> ${TEMP_DIR}/liferay/tomcat/bin/setenv.sh
}

function date {
	export LC_ALL=en_US.UTF-8
	export TZ=America/Los_Angeles

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

function download {
	local file_name=${1}
	local file_url=${2}

	if [ -e ${file_name} ] && [[ ${file_url} != */nightly/* ]] && [[ ${file_url} != */latest/* ]]
	then
		return
	fi

	if [[ ${file_url} != http*://* ]]
	then
		file_url=http://${file_url}
	fi

	if [[ ${file_url} != http://mirrors.*.liferay.com* ]] &&
	   [[ ${file_url} != http://release-1* ]] &&
	   [[ ${file_url} != https://release.liferay.com* ]]
	then
		if [ ! -n "${LIFERAY_DOCKER_MIRROR}" ]
		then
			LIFERAY_DOCKER_MIRROR=lax
		fi

		file_url=http://mirrors.${LIFERAY_DOCKER_MIRROR}.liferay.com/${file_url##*//}
	fi

	echo ""
	echo "Downloading ${file_url}."
	echo ""

	mkdir -p $(dirname ${file_name})

	curl ${LIFERAY_DOCKER_CURL_OPTIONS} -f -o ${file_name} ${file_url} || exit 2
}

function get_docker_image_tags_args {
	local docker_image_tags_args=""

	for docker_image_tag in "${@}"
	do
		docker_image_tags_args="${docker_image_tags_args} --tag ${docker_image_tag}"
	done

	echo ${docker_image_tags_args}
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

function make_temp_directory {
	CURRENT_DATE=$(date)

	TIMESTAMP=$(date "${CURRENT_DATE}" "+%Y%m%d%H%M%S")

	TEMP_DIR=temp-${TIMESTAMP}

	mkdir -p ${TEMP_DIR}

	cp -r ${1}/* ${TEMP_DIR}
}

function pid_8080 {
	local pid=`lsof -i 4tcp:8080 -sTCP:LISTEN -Fp | head -n 1`

	echo ${pid##p}
}

function prepare_tomcat {
	local liferay_tomcat_version=$(get_tomcat_version ${TEMP_DIR}/liferay)

	mv ${TEMP_DIR}/liferay/tomcat-${liferay_tomcat_version} ${TEMP_DIR}/liferay/tomcat

	ln -s tomcat ${TEMP_DIR}/liferay/tomcat-${liferay_tomcat_version}

	configure_tomcat

	warm_up_tomcat

	rm -fr ${TEMP_DIR}/liferay/logs/*
	rm -fr ${TEMP_DIR}/liferay/tomcat/logs/*
}

function push_docker_images {
	if [ "${1}" == "push" ]
	then
		for docker_image_tag in "${DOCKER_IMAGE_TAGS[@]}"
		do
			docker sign trust ${docker_image_tag}
			docker push ${docker_image_tag}
		done
	fi
}

function start_tomcat {

	#
	# Increase the available memory for warming up Tomcat. This is needed
	# because LPKG hash and OSGi state processing for 7.0.x is expensive. Set
	# this for all scenarios since it is limited to warming up Tomcat.
	#

	LIFERAY_JVM_OPTS="-Xmx3G"

	local pid=$(pid_8080)

	if [ -n "${pid}" ]
	then
		echo ""
		echo "Killing process ${pid} that is listening on port 8080."
		echo ""

		kill -9 ${pid} 2>/dev/null
	fi

	./${TEMP_DIR}/liferay/tomcat/bin/catalina.sh start

	until $(curl --head --fail --output /dev/null --silent http://localhost:8080)
	do
		sleep 3
	done

	pid=$(pid_8080)

	./${TEMP_DIR}/liferay/tomcat/bin/catalina.sh stop

	sleep 30

	kill -9 ${pid} 2>/dev/null

	rm -fr ${TEMP_DIR}/liferay/data/osgi/state
	rm -fr ${TEMP_DIR}/liferay/osgi/state
}

function stat {
	if [ "$(uname)" == "Darwin" ]
	then
		echo $(/usr/bin/stat -f "%z" "${1}")
	else
		echo $(/usr/bin/stat --printf="%s" "${1}")
	fi
}

function test_docker_image {
	export LIFERAY_DOCKER_IMAGE_ID="${DOCKER_IMAGE_TAGS[0]}"

	./test_image.sh

	if [ $? -gt 0 ]
	then
		echo "Testing failed, exiting."

		exit 2
	fi
}

function warm_up_tomcat {

	#
	# Warm up Tomcat for older versions to speed up starting Tomcat. Populating
	# the Hypersonic files can take over 20 seconds.
	#

	if [ -d ${TEMP_DIR}/liferay/data/hsql ]
	then
		if [ $(stat ${TEMP_DIR}/liferay/data/hsql/lportal.script) -lt 1024000 ]
		then
			start_tomcat
		else
			echo Tomcat is already warmed up.
		fi
	fi

	if [ -d ${TEMP_DIR}/liferay/data/hypersonic ]
	then
		if [ $(stat ${TEMP_DIR}/liferay/data/hypersonic/lportal.script) -lt 1024000 ]
		then
			start_tomcat
		else
			echo Tomcat is already warmed up.
		fi
	fi
}