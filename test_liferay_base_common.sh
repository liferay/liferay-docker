#!/bin/bash

source ./_test_common.sh

function main {
	set_up

	test_liferay_base_common_forward_signals_and_wait

	tear_down
}

function set_up {
	export _TEST_DIR=$(mktemp --directory)

	cat <<- EOF > "${_TEST_DIR}/app.sh"
	#!/bin/bash

	trap 'sleep 1; echo stopped; exit 3' TERM

	echo "started"

	for counter in {1..100}
	do
		sleep 0.1
	done
	EOF

	cat <<- EOF > "${_TEST_DIR}/entrypoint.sh"
	#!/bin/bash

	source "${PWD}/templates/base/resources/usr/local/bin/_liferay_base_common.sh"

	bash "${_TEST_DIR}/app.sh" &

	forward_signals_and_wait "\${!}"

	echo "exit code \${?}"
	EOF
}

function tear_down {
	rm --force --recursive "${_TEST_DIR}"

	unset _TEST_DIR
}

function test_liferay_base_common_forward_signals_and_wait {
	bash "${_TEST_DIR}/entrypoint.sh" > "${_TEST_DIR}/output" &

	local entrypoint_pid=${!}

	local counter

	for counter in {1..50}
	do
		if grep --fixed-strings --quiet "started" "${_TEST_DIR}/output"
		then
			break
		fi

		sleep 0.1
	done

	kill -TERM "${entrypoint_pid}"

	wait "${entrypoint_pid}"

	assert_equals \
		"$(cat "${_TEST_DIR}/output")" \
		"$(echo -e "started\nstopped\nexit code 3")"
}

main