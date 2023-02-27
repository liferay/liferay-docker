#!/bin/bash

function check_usage {
	if [ ! -e document_library ]
	then
		if [ -e /opt/liferay/data ]
		then
			cd /opt/liferay/data || exit 3
		else
			echo "Run this script from the Liferay data directory, which contains document_library."

			exit 1
		fi
	fi
}

function generate_data {
	rm -fr "${TMP_DIR}"
	mkdir -p "${TMP_DIR}"

	cd document_library || exit 3

	pwd=$(pwd)

	for companyId in *
	do
		if [ ! -d "${pwd}/${companyId}" ]
		then
			continue
		fi

		cd "${pwd}/${companyId}" || exit 3

		mkdir -p "${TMP_DIR}/${companyId}"

		cd "${pwd}/${companyId}/0" || exit 3

		for dir in adaptive document_preview document_thumbnail
		do
			generated_dir_size "${dir}" >> "${TMP_DIR}/${companyId}/generated_files"
		done

		cd "${pwd}/${companyId}" || exit 3

		for repository in *
		do
			if [[ "${repository}" -eq 0 ]] || [ ! -d "${pwd}/${companyId}/${repository}" ] || [[ $(find "${pwd}/${companyId}/${repository}" -maxdepth 1 -mindepth 1 | wc -l 2>/dev/null) -eq 0 ]]
			then
				continue
			fi

			cd "${pwd}/${companyId}/${repository}" || exit 3

			for file in *
			do
				cd "${pwd}/${companyId}/${repository}/${file}" || exit 3

				if [[ $(find . -maxdepth 1 -mindepth 1 | wc -l) -gt 0 ]]
				then
					for version in *
					do
						local file_path="${companyId}/${repository}/${file}/${version}"

						local full_type=$(file -b "${version}")
						local type=${full_type%% *}

						if [[ ${type} == "Zip" ]]
						then
							if (! unzip -l "${version}" &>/dev/null)
							then
								type="BrokenZip"
							elif (unzip -l "${version}" | grep manifest.xml &>/dev/null)
							then
								type="LAR"

								if [[ $(find "${version}" -ctime +29 | wc -l) -gt 0 ]]
								then
									echo "${file_path}" >> "${TMP_DIR}/${companyId}/lar_30_days"
								elif [[ $(find "${version}" -ctime +6 | wc -l) -gt 0 ]]
								then
									echo "${file_path}" >> "${TMP_DIR}/${companyId}/lar_7_days"
								fi
							fi
						fi

						if [[ ${type} == "ISO" ]]
						then
							if (echo "${full_type}" | grep MP4 &>/dev/null)
							then
								type=MP4
							fi
						fi

						local size=$(stat --printf="%s" "${version}")
						local md5=$(md5sum "${version}" | sed -e "s/\ .*//")

						echo "${size} ${md5}" >> "${TMP_DIR}/${companyId}/type_$type"
						echo "${file_path} ${type} ${size} ${md5} ${full_type})" >> "${TMP_DIR}/${companyId}/all"
					done
				fi
			done
		done
	done
}

function generated_dir_size {
	local size=$(du -s "${1}" 2>/dev/null)

	if [ -n "${size}" ]
	then
		size=$(echo "${size}" | sed -e s/[^0-9]*//g)
		size=$((size / 1024))

		local count=$(find "${1}" -type f | wc -l)

		echo "${1},${count},${count},${size},${size}"
	fi
}

function main {
	TMP_DIR=/tmp/dl_inspect_cache

	check_usage

	if [ -e ${TMP_DIR} ]
	then
		echo "${TMP_DIR} exists from a previous run, not calculating again."
	else
		generate_data
	fi

	print_data
}

function print_data {
	cd "${TMP_DIR}" || exit 3

	for companyId in *
	do
		cd "${companyId}" || exit 3

		echo "CSV Data for company ${companyId}"
		echo ""
		echo "Type,Count,Unique count,Size MB,Unique size MB"

		cat generated_files

		for type in type_*
		do
			type=${type#type_}
			echo -en "${type},"

			local count=$(wc -l "type_${type}" | sed -e "s/\ .*//")
			echo -en "${count},"

			local unique=$(sed -e "s/.*\ //" < "type_${type}"| sort | uniq | wc -l)
			echo -en "${unique},"

			local size=$(sed -e "s/\ .*//" < "type_${type}"| tr '\n' '+' | sed -e "s/\+$/\n/" | bc)
			size=$((size / 1048576))
			echo -en "${size},"

			local unique_size=$(sort < "type_${type}"| uniq | sed -e "s/\ .*//" | tr '\n' '+' | sed -e "s/\+$/\n/" | bc)
			unique_size=$((unique_size / 1048576))
			echo -en "${unique_size}"

			echo ""
		done

		echo ""

		if [ -e lar_7_days ]
		then
			echo "More than 7 days old LAR files:"

			cat lar_7_days
		fi

		if [ -e lar_30_days ]
		then
			echo "More than 30 days old LAR files:"

			cat lar_30_days
		fi

		cd "${TMP_DIR}" || exit 3
	done
}

main