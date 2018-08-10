#!/bin/bash

function main {
	local release_file_name=${1##*/}
	local release_file_url=http://mirrors.lax.liferay.com/${1}

	local current_date=$(date)

	local timestamp=`date -d "${current_date}" "+%Y%m%d%H%M"`

	mkdir -p ${timestamp}

	cp -r template/* ${timestamp}
	cp -r template/.bashrc ${timestamp}

	local docker_image_name
	local product_name

	if [[ ${release_file_name} == *-commerce-* ]]
	then
		docker_image_name="commerce"
		product_name="Liferay Commerce"
	elif [[ ${release_file_name} == *-dxp-* ]]
	then
		docker_image_name="dxp"
		product_name="Liferay DXP"
	elif [[ ${release_file_name} == *-emporio-* ]]
	then
		docker_image_name="emporio"
		product_name="Liferay Emporio"
	elif [[ ${release_file_name} == *-portal-* ]]
	then
		docker_image_name="portal"
		product_name="Liferay Portal"
	else
		echo "${release_file_name} is an unsupported release file name."

		exit
	fi

	sed -i "s/\[\$PRODUCT_NAME\$\]/${product_name}/" ${timestamp}/entrypoint.sh

	if [ ! -e releases/${release_file_name} ]
	then
		echo ""
		echo "Downloading ${release_file_url}."
		echo ""

		curl -o releases/${release_file_name} ${release_file_url}
	fi

	unzip -q releases/${release_file_name} -d ${timestamp}

	mv ${timestamp}/liferay-* ${timestamp}/liferay

	mv ${timestamp}/liferay/tomcat-* ${timestamp}/liferay/tomcat

	warm_up_tomcat ${timestamp}

	local docker_image_tag=${release_file_url%/*}

	docker_image_tag=liferay/${docker_image_name}:${docker_image_tag##*/}

	docker build \
		--build-arg LABEL_BUILD_DATE=`date -d "${current_date}" +'%Y-%m-%dT%H:%M:%SZ'` \
		--build-arg LABEL_NAME="${product_name}" \
		--tag ${docker_image_tag}-latest \
		--tag ${docker_image_tag}-${timestamp} \
		${timestamp}

	#docker push ${docker_image_tag}-latest
	#docker push ${docker_image_tag}-${timestamp}

	// TODO Automatically push to Docker Hub
	// TODO Support for DXP licenses
	// TODO Support for nightly

	rm -fr ${timestamp}
}

function start_tomcat {
	local timestamp=${1}

	./${timestamp}/liferay/tomcat/bin/catalina.sh start

	until $(curl --head --fail --output /dev/null --silent http://localhost:8080)
	do
		sleep 3
	done

	./${timestamp}/liferay/tomcat/bin/catalina.sh stop

	sleep 10

	rm -fr ${timestamp}/liferay/data/osgi/state
	rm -fr ${timestamp}/liferay/osgi/state
	rm -fr ${timestamp}/liferay/tomcat/logs/*
}

function warm_up_tomcat {
	local timestamp=${1}

	if [ -d ${timestamp}/liferay/data/hsql ]
	then
		if [ ! -d ${timestamp}/liferay/data/hsql/lportal.tmp ]
		then
			start_tomcat ${timestamp}
		fi
	fi

	if [ -d ${timestamp}/liferay/data/hypersonic ]
	then
		if [ ! -d ${timestamp}/liferay/data/hypersonic/lportal.tmp ]
		then
			start_tomcat ${timestamp}
		fi
	fi
}

main ${1}