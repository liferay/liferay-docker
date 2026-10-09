#!/bin/bash

source ./_liferay_common.sh
source ./_test_common.sh

function main {
	set_up

	if [[ "${#}" -eq 1 ]]
	then
		"${1}"
	else
		test_build_jar_runner_image_forwards_sigterm_to_java
		test_build_jar_runner_image_runs_tear_down_script_after_sigterm
	fi

	tear_down
}

function set_up {
	export _TEST_APP_DIR=$(mktemp --directory)

	cp --recursive templates/jar-runner "${_TEST_APP_DIR}/jar-runner"

	mkdir --parents "${_TEST_APP_DIR}/jar-runner/resources/etc"

	date > "${_TEST_APP_DIR}/jar-runner/resources/etc/created-date"

	export _TEST_JAR_RUNNER_IMAGE="liferay/jar-runner:test"

	docker build --tag "${_TEST_JAR_RUNNER_IMAGE}" "${_TEST_APP_DIR}/jar-runner" &> /dev/null

	cat <<- EOF > "${_TEST_APP_DIR}/App.java"
	public class App {

		public static void main(String[] args) throws Exception {
			Runtime.getRuntime().addShutdownHook(
				new Thread(
					() -> System.out.println(
						"[LIFERAY_JAR_RUNNER_TEST] shutdown hook")));

			System.out.println("[LIFERAY_JAR_RUNNER_TEST] started");

			Thread.sleep(600000);
		}

	}
	EOF

	cat <<- EOF > "${_TEST_APP_DIR}/liferay_jar_runner_tear_down.sh"
	#!/bin/bash

	echo "[LIFERAY_JAR_RUNNER_TEST] tear down"
	EOF

	cat <<- EOF > "${_TEST_APP_DIR}/Dockerfile"
	FROM ${_TEST_JAR_RUNNER_IMAGE}

	COPY --chown=liferay:liferay App.java /tmp/

	COPY --chmod=755 liferay_jar_runner_tear_down.sh /usr/local/bin/

	RUN cd /tmp && \
		/usr/lib/jvm/zulu21/bin/javac App.java && \
		echo "Main-Class: App" > manifest.txt && \
		/usr/lib/jvm/zulu21/bin/jar --create --file /opt/liferay/jar-runner.jar --manifest manifest.txt App.class
	EOF

	export _TEST_DERIVED_IMAGE="liferay/jar-runner-derived:test"

	docker build --tag "${_TEST_DERIVED_IMAGE}" "${_TEST_APP_DIR}" &> /dev/null
}

function tear_down {
	docker rmi --force "${_TEST_DERIVED_IMAGE}" &> /dev/null
	docker rmi --force "${_TEST_JAR_RUNNER_IMAGE}" &> /dev/null

	rm --force --recursive "${_TEST_APP_DIR}"

	unset _TEST_APP_DIR
	unset _TEST_DERIVED_IMAGE
	unset _TEST_JAR_RUNNER_IMAGE
}

function test_build_jar_runner_image_forwards_sigterm_to_java {
	assert_equals \
		"$(_test_build_jar_runner_image_stop_container | grep --fixed-strings "[LIFERAY_JAR_RUNNER_TEST] shutdown hook")" \
		"[LIFERAY_JAR_RUNNER_TEST] shutdown hook"
}

function test_build_jar_runner_image_runs_tear_down_script_after_sigterm {
	assert_equals \
		"$(_test_build_jar_runner_image_stop_container | grep --fixed-strings "[LIFERAY_JAR_RUNNER_TEST] tear down")" \
		"[LIFERAY_JAR_RUNNER_TEST] tear down"
}

function _test_build_jar_runner_image_stop_container {
	local container_id=$(docker run --detach "${_TEST_DERIVED_IMAGE}")

	local attempt

	for attempt in {1..30}
	do
		if docker logs "${container_id}" 2>&1 | grep --fixed-strings --quiet "[LIFERAY_JAR_RUNNER_TEST] started"
		then
			break
		fi

		sleep 1
	done

	docker stop --time 20 "${container_id}" &> /dev/null

	docker logs "${container_id}" 2>&1

	docker rm --force "${container_id}" &> /dev/null
}

main "${@}"