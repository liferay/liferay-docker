#!/bin/bash

function check_usage {
	if [ ! -e document_library ]
	then
		cd /opt/liferay/data &>/dev/null
	fi

	if [ ! -e document_library ]
	then
		echo "Run this script from the Liferay data directory, which contains document_library."

		exit 1
	fi
}

function generated_dir_size {
	local size=$(du -s ${1} 2>/dev/null)

	if [ -n "${size}" ]
	then
		size=$(echo ${size} | sed -e s/[^0-9]*//g)
		size=$((size / 1024))

		local count=$(find ${1} -type f | wc -l)

		echo ${1},${count},${count},${size},${size}
	fi
}

function generate_data {
	rm -fr ${TMP_DIR}
	mkdir -p ${TMP_DIR}

	cd document_library

	pwd=$(pwd)

	for companyId in *
	do
		if [ ! -d ${pwd}/${companyId} ]
		then
			continue
		fi

		cd ${pwd}/${companyId}

		mkdir -p ${TMP_DIR}/${companyId}

		cd ${pwd}/${companyId}/0

		for dir in adaptive document_preview document_thumbnail
		do
			generated_dir_size ${dir} >> ${TMP_DIR}/${companyId}/generated_files
		done

		cd ${pwd}/${companyId}

		for repository in *
		do
			if [[ ${repository} -eq 0 ]] || [ ! -d ${pwd}/${companyId}/${repository} ] || (! ls ${pwd}/${companyId}/${repository} | grep . &>/dev/null)
			then
				continue
			fi

			cd ${pwd}/${companyId}/${repository}

			for file in *
			do
				cd ${pwd}/${companyId}/${repository}/${file}

				if (ls | grep . &>/dev/null)
				then
					for version in *
					do
						local full_type=$(file -b ${version})
						local type=${full_type%% *}

						if [[ ${type} == "Zip" ]]
						then
							if (! unzip -l ${version} &>/dev/null)
							then
								type="BrokenZip"
							elif (unzip -l ${version} | grep manifest.xml &>/dev/null)
							then
								type="LAR"
							fi
						fi

						if [[ ${type} == "ISO" ]]
						then
							if (echo ${full_type} | grep MP4 &>/dev/null)
							then
								type=MP4
							fi
						fi

						local size=$(stat --printf="%s" ${version})
						local md5=$(md5sum ${version} | sed -e "s/\ .*//")

						echo ${size} ${md5} >> ${TMP_DIR}/${companyId}/type_$type
						echo "${companyId}/${repository}/${file}/${version} ${type} ${size} ${md5} ${full_type})" >> ${TMP_DIR}/${companyId}/all
					done
				fi
			done
		done
	done
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
	cd ${TMP_DIR}

	for companyId in *
	do
		cd ${companyId}

		echo "CSV Data for company ${companyId}"
		echo ""
		echo "Type,Count,Unique count,Size MB,Unique size MB"

		cat generated_files

		for type in $(ls type_* 2>/dev/null)
		do
			type=${type#type_}
			echo -en "${type},"

			local count=$(wc -l type_${type} | sed -e "s/\ .*//")
			echo -en "${count},"

			local unique=$(cat type_${type} | sed -e "s/.*\ //" | sort | uniq | wc -l)
			echo -en "${unique},"

			local size=$(cat type_${type} | sed -e "s/\ .*//" | tr '\n' '+' | sed -e "s/\+$/\n/" | bc)
			size=$((size / 1048576))
			echo -en "${size},"

			local unique_size=$(cat type_${type} | sort | uniq | sed -e "s/\ .*//" | tr '\n' '+' | sed -e "s/\+$/\n/" | bc)
			unique_size=$((unique_size / 1048576))
			echo -en "${unique_size}"

			echo ""
		done

		echo ""

		cd ..
	done
}

main