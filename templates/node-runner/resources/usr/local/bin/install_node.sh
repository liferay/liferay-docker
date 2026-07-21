#!/bin/bash

function main {
	local node_version=${1}
	local target_dir=${2}

	local node_architecture

	local architecture=$(dpkg --print-architecture)

	if [ "${architecture}" == "amd64" ]
	then
		node_architecture="x64"
	elif [ "${architecture}" == "arm64" ]
	then
		node_architecture="arm64"
	else
		echo "[LIFERAY] Unsupported architecture: ${architecture}."

		exit 1
	fi

	mkdir --parents "${target_dir}"

	curl \
		--fail \
		--location \
		--show-error \
		--silent \
		"https://nodejs.org/dist/v${node_version}/node-v${node_version}-linux-${node_architecture}.tar.gz" | \
		tar \
			--directory "${target_dir}" \
			--extract \
			--gzip \
			--strip-components 1

	"${target_dir}/bin/node" --version
}

main "${@}"
