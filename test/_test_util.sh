#!/bin/bash

function add_release_to_test_dependency {
	local release_path="dxp"

	if [[ "${1}" =~ -[0-9]+$ ]]
	then
		release_path="${release_path}/release-candidates"
	fi

	local release=$(
		cat <<- END
		<li>
			<a href="/${release_path}/${1}" class="icon icon-directory" title="${1}">
				<span class="name">${1}</span>
				<span class="size"></span>
				<span class="date">01/01/2026 12:00:00 PM</span>
			</a>
		</li>
		END
	)

	release="${release//$'\n'/\\n}"

	sed --in-place "/<\/ul>/i \\${release}" "${2}"
}