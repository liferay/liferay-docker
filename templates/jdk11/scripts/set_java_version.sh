#!/bin/bash

function create_symlink {
	if [[ -e /usr/lib/jvm/"${1}"-"${ARC}" ]] && [[ ! -e /usr/lib/jvm/"${1//-/}" ]]
	then
		ln -sf /usr/lib/jvm/"${1}"-"${ARC}" /usr/lib/jvm/"${1//-/}"
	fi
}

function main {
	ARC=$(dpkg --print-architecture)

	create_symlink "zulu-8"
	create_symlink "zulu-11"

	if [ -n "${JAVA_VERSION}" ]
	then
		if [ -e "/usr/lib/jvm/${JAVA_VERSION}" ]
		then
			JAVA_HOME=/usr/lib/jvm/${JAVA_VERSION}
			PATH=/usr/lib/jvm/${JAVA_VERSION}/bin/:${PATH}

			local zulu_version=$(echo "${JAVA_VERSION}" | tr -dc '0-9')
			update-java-alternatives -s zulu-"${zulu_version}"-"${ARC}"

			echo "[LIFERAY] Using ${JAVA_VERSION} JDK. You can use another JDK by setting the \"JAVA_VERSION\" environment varible."
			echo ""
		else
			echo "[LIFERAY] \"${JAVA_VERSION}\" JDK is not available in this Docker image."
			echo ""

			exit 1
		fi
	fi
}

main