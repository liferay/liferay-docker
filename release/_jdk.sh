#!/bin/bash

function configure_jdk {
	if (java -version | grep -q 1.8.0_381)
	then
		echo "Java is already at 1.8.0_381."

		return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
	fi

	lc_cd "${_RELEASE_ROOT_DIR}"

	if [ ! -e jdk ]
	then
		echo "Installing JDK."

		lc_download https://cdn.azul.com/zulu/bin/zulu8.72.0.17-ca-jdk8.0.382-linux_x64.tar.gz

		tar -xzf zulu8.72.0.17-ca-jdk8.0.382-linux_x64.tar.gz

		mv zulu8.72.0.17-ca-jdk8.0.382-linux_x64 jdk
	fi

	lc_cd jdk

	export JAVA_HOME=$(pwd)
	export PATH="${JAVA_HOME}/bin:${PATH}"

	if (java -version | grep -q 1.8.0_381)
	then
		echo "Java version setup is unsuccessful."

		return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
	fi

}