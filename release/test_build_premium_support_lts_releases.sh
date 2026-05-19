#!/bin/bash

source ../_liferay_common.sh
source ../_test_common.sh
source ./build_premium_support_lts_releases.sh

function main {
	set_up

	test_build_premium_support_lts_releases_process_premium_support_lts_release_branches

	tear_down
}

function set_up {
	common_set_up

	export LIFERAY_RELEASE_TEST_DATE="2025-06-01"
	export _RELEASE_ROOT_DIR="${PWD}"
}

function tear_down {
	common_tear_down

	unset LIFERAY_RELEASE_TEST_DATE
	unset _RELEASE_ROOT_DIR
}

function test_build_premium_support_lts_releases_process_premium_support_lts_release_branches {
	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		"$(echo -e 'release-2023.q1\nrelease-2024.q1\nrelease-2025.q1')"

	LIFERAY_RELEASE_TEST_DATE="2026-06-01"

	local latest_release=$(
		cat <<- END
		<li>
			<a href="/dxp/2026.q1.9" class="icon icon-directory" title="2026.q1.9">
				<span class="name">2026.q1.9</span>
				<span class="size"></span>
				<span class="date">06/01/2026 12:00:00 PM</span>
			</a>
		</li>
		END
	)

	latest_release="${latest_release//$'\n'/\\n}"

	sed --in-place "/<\/ul>/i \\${latest_release}" test-dependencies/actual/dxp.html

	local latest_release_candidate=$(
		cat <<- END
		<li>
			<a href="/dxp/release-candidates/2026.q1.9-1812345678" class="icon icon-directory" title="2026.q1.9-1812345678">
				<span class="name">2026.q1.9-1812345678</span>
				<span class="size"></span>
				<span class="date">06/01/2026 12:00:00 PM</span>
			</a>
		</li>
		END
	)

	latest_release_candidate="${latest_release_candidate//$'\n'/\\n}"

	sed --in-place "/<\/ul>/i \\${latest_release_candidate}" test-dependencies/actual/release-candidates.html

	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		"$(echo -e 'release-2024.q1\nrelease-2025.q1')"

	git restore test-dependencies/actual/dxp.html test-dependencies/actual/release-candidates.html

	latest_release_candidate=$(
		cat <<- END
		<li>
			<a href="/dxp/release-candidates/2025.q2.9-1754280641" class="icon icon-directory" title="2025.q2.9-1754280641">
				<span class="name">2025.q2.9-1754280641</span>
				<span class="size"></span>
				<span class="date">12/23/2025 12:32:16 PM</span>
			</a>
		</li>
		END
	)

	latest_release_candidate="${latest_release_candidate//$'\n'/\\n}"

	sed --in-place "/<\/ul>/i \\${latest_release_candidate}" test-dependencies/actual/release-candidates.html

	_test_build_premium_support_lts_releases_process_premium_support_lts_release_branches \
		"$(echo -e 'release-2024.q1\nrelease-2025.q1\nrelease-2026.q1')"

	git restore test-dependencies/actual/release-candidates.html
}

function _test_build_premium_support_lts_releases_process_premium_support_lts_release_branches {
	local triggered_branches=$(_process_premium_support_lts_release_branches 2>/dev/null | grep "^release-")

	assert_equals \
		"${triggered_branches}" "${1}"
}

main "${@}"
