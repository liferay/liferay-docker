#!/bin/bash

function main {

	#
	# Make temporary directory.
	#

	local current_date=$(date)

	local timestamp=$(date -d "${current_date}" "+%Y%m%d%H%M")

	mkdir -p ${timestamp}

	cp -r template/* ${timestamp}
	cp -r template/.bashrc ${timestamp}

	#
	# Download and prepare release.
	#

	local release_dir=${1%/*}

	release_dir=${release_dir#*com/}
	release_dir=${release_dir#*com/}
	release_dir=${release_dir#*private/ee/}
	release_dir=releases/${release_dir}

	local release_file_name=${1##*/}

	local release_file_url=${1}

	if [[ ${release_file_url} != http://mirrors.lax.liferay.com* ]]
	then
		release_file_url=http://mirrors.lax.liferay.com/${release_file_url}
	fi

	if [ ! -e ${release_dir}/${release_file_name} ]
	then
		echo ""
		echo "Downloading ${release_file_url}."
		echo ""

		mkdir -p ${release_dir}

		curl -o ${release_dir}/${release_file_name} ${release_file_url}
	fi

	if [[ ${release_file_name} == *.7z ]]
	then
		7z x -O${timestamp} ${release_dir}/${release_file_name}
	else
		unzip -q ${release_dir}/${release_file_name} -d ${timestamp}
	fi

	mv ${timestamp}/liferay-* ${timestamp}/liferay

	if [ -e ${timestamp}/liferay/tomcat-* ]
	then
		mv ${timestamp}/liferay/tomcat-* ${timestamp}/liferay/tomcat
	fi

	#
	# Warm up Tomcat for older versions to speed up starting Tomcat. Populating
	# the Hypersonic files can take over 20 seconds.
	#

	warm_up_tomcat ${timestamp}

	#
	# Download trial DXP license.
	#

	if [[ ${release_file_name} == *-dxp-* ]]
	then
		if [ -z "${LIFERAY_DOCKER_LICENSE_CMD}" ]
		then
			echo "Please set the environment variable LIFERAY_DOCKER_LICENSE_CMD to generate a trial DXP license."

			exit
		else
			mkdir -p ${timestamp}/liferay/deploy

			license_file_name=license-$(date -d "${current_date}" +%Y%m%d).xml

			eval "curl --silent --header \"${LIFERAY_DOCKER_LICENSE_CMD}?licenseLifetime=$(expr 1000 \* 60 \* 60 \* 24 \* 30)&startDate=$(date -d "${current_date}" "+%Y-%m-%d")&owner=ci%40wedeploy.com\" > ${timestamp}/liferay/deploy/${license_file_name}"

			sed -i "s/\\\n//g" ${timestamp}/liferay/deploy/${license_file_name}
			sed -i "s/\\\t//g" ${timestamp}/liferay/deploy/${license_file_name}
			sed -i "s/\"<?xml/<?xml/" ${timestamp}/liferay/deploy/${license_file_name}
			sed -i "s/license>\"/license>/" ${timestamp}/liferay/deploy/${license_file_name}
			sed -i 's/\\"/\"/g' ${timestamp}/liferay/deploy/${license_file_name}
		fi
	fi

	#
	# Build Docker image.
	#

	local docker_image_name
	local label_name

	if [[ ${release_file_name} == *-commerce-* ]]
	then
		docker_image_name="commerce"
		label_name="Liferay Commerce"
	elif [[ ${release_file_name} == *-dxp-* ]] || [[ ${release_file_name} == *-private* ]]
	then
		docker_image_name="dxp"
		label_name="Liferay DXP"
	elif [[ ${release_file_name} == *-emporio-* ]]
	then
		docker_image_name="emporio"
		label_name="Liferay Emporio"
	elif [[ ${release_file_name} == *-portal-* ]]
	then
		docker_image_name="portal"
		label_name="Liferay Portal"
	else
		echo "${release_file_name} is an unsupported release file name."

		exit
	fi

	if [[ ${release_file_url%} == */snapshot-* ]]
	then
		docker_image_name=${docker_image_name}-snapshot
	fi

	local release_version=${release_file_url%/*}

	release_version=${release_version##*/}

	local label_version=${release_version}

	if [[ ${release_file_url%} == */snapshot-* ]]
	then
		local release_branch=${release_file_url%/*}

		release_branch=${release_branch%/*}
		release_branch=${release_branch%-private*}
		release_branch=${release_branch##*-}

		local release_hash=$(cat ${timestamp}/liferay/.githash)

		label_version="${release_branch} Snapshot on ${label_version} at ${release_hash}"
	fi

	local primary_docker_image_tag=liferay/${docker_image_name}:${release_version}
	local secondary_docker_image_tag=liferay/${docker_image_name}:${release_version}-${timestamp}

	if [[ ${release_file_url%} == */snapshot-* ]]
	then
		primary_docker_image_tag=liferay/${docker_image_name}:${release_branch}
		secondary_docker_image_tag=liferay/${docker_image_name}:${release_branch}-${release_version}-${release_hash}
	fi

	docker build \
		--build-arg LABEL_BUILD_DATE=$(date -d "${current_date}" +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg LABEL_NAME="${label_name}" \
		--build-arg LABEL_VCS_REF=$(git rev-parse HEAD) \
		--build-arg LABEL_VERSION="${label_version}" \
		--tag ${primary_docker_image_tag} \
		--tag ${secondary_docker_image_tag} \
		${timestamp}

	#
	# Push Docker image.
	#

	#docker push ${primary_docker_image_tag}

	#
	# Clean up temporary directory.
	#

	rm -fr ${timestamp}

	# TODO Automatically push to Docker Hub
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
		if [ $(stat --printf="%s" ${timestamp}/liferay/data/hsql/lportal.script) -lt 1024000 ]
		then
			start_tomcat ${timestamp}
		else
			echo Tomcat is already warmed up.
		fi
	fi

	if [ -d ${timestamp}/liferay/data/hypersonic ]
	then
		if [ $(stat --printf="%s" ${timestamp}/liferay/data/hypersonic/lportal.script) -lt 1024000 ]
		then
			start_tomcat ${timestamp}
		else
			echo Tomcat is already warmed up.
		fi
	fi
}

main ${1}