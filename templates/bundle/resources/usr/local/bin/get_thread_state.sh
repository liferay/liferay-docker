#!/bin/bash

function compare {
	local total=0
	local match=0

	while read -r name state hash
	do
		((total++))
		found=$(awk -v n="${name}" -v s="${state}" -v h="${hash}" \
			'$1==n && $2==s && $3==h {print}' "${2}")
		[[ -n "${found}" ]] && ((match++))
	done < "${1}"

	if (( total == 0 ))
	then
		echo 0
	else
		echo $(( match * 100 / total ))
	fi
}

function filter_threads {
	awk '
	BEGIN { capture=0; stack="" }
	/^"/ {
		if ($0 ~ /catalina-exec-/ || $0 ~ /http-nio-8081-exec/) {
			capture=1
			sub(/#.*/, "", $0)
			stack = $0 "\n"
		} else {
			capture=0
		}
	}
	capture && !/^"/ { stack = stack $0 "\n" }
	capture && /^$/ { print stack; capture=0; stack="" }
	END { if (capture) print stack }
	' "${1}"
}

function main {
	for i in {1..3}
	do
		jcmd "$(cat "${LIFERAY_PID}")" Thread.print > "${LIFERAY_HOME}/dump_${i}.tdump"

		if [ "${i}" -lt 3 ]
		then
			sleep 5
		fi
	done

	for i in {1..3}
	do
		filter_threads "${LIFERAY_HOME}/dump_${i}.tdump" | parse_threads > "${LIFERAY_HOME}/filter_${i}.tdump"
		if [ ! -s "${LIFERAY_HOME}/filter_${i}.tdump" ]
		then
			echo "Lifecycle monitor: Empty filtered thread found in filter_${i}.tdump."
			exit 0
		fi
	done

	for i in {1..2}
	do
		comparison[$i]=$(compare "${LIFERAY_HOME}/filter_1.tdump" "${LIFERAY_HOME}/filter_$((i+1)).tdump")
		echo "Lifecycle monitor: Match dump_1 & dump_$((i+1)): ${comparison[$i]}%."
	done

	if (( "${comparison[1]}" == 100 && "${comparison[2]}" == 100 ))
	then
		echo "Lifecycle monitor: All dumps match perfectly."
		exit 2
	elif (( "${comparison[1]}" >= 90 && "${comparison[2]}" >= 90 ))
	then
		echo "Lifecycle monitor: Baseline matches >=90% with both dumps."
		exit 2
	elif (( "${comparison[1]}" >= 90 || "${comparison[2]}" >= 90 ))
	then
		echo "Lifecycle monitor: Only one comparison met >=90% threshold."
		exit 1
	else
		echo "Lifecycle monitor: Both comparisons below threshold."
		exit 0
	fi
}

function parse_threads {
	awk -v tmpdir="${LIFERAY_HOME}" '
	BEGIN { RS=""; FS="\n" }
	{
		if ($1 ~ /catalina-exec-|http-nio-8081-exec/) {
			state=""
			stack=""
			stack_lines=0
			for (i=1; i<=NF; i++) {
				stack = stack $i "\n"
				if ($i ~ /java\.lang\.Thread\.State:/) {
					if (match($i, /java\.lang\.Thread\.State:\s*([A-Z_]+)/, m)) {
						state = m[1]
					}
				}
				if ($i ~ /^\s*at /) stack_lines++
			}
			if (stack_lines <= 30) next
			tmpfile = sprintf("%s/.tmpstack_%d", tmpdir, NR)
			print stack > tmpfile
			close(tmpfile)
			cmd = "sha256sum \"" tmpfile "\""
			cmd | getline hashline
			close(cmd)
			split(hashline, parts, " ")
			hash = parts[1]
			system("rm -f \"" tmpfile "\"")
			if (match($1, /"(catalina-exec-[^"]+|http-nio-8081-exec[^"]+)"/, m)) {
				tname = m[1]
				print tname, state, hash
			}
		}
	}'
}

main