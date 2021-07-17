#!/usr/bin/env bash

set -e

bold="\e[1m"
red="\e[31m"
cyan="\e[36m"
blue="\e[34m"
reset="\e[0m"
green="\e[32m"
yellow="\e[33m"
underline="\e[4m"
script_file_name=${0##*/}

target=False
output_directory="."
port_scan_workflow="nmap2nmap"
port_scan_workflows=(nmap2nmap naabu2nmap masscan2nmap)

steps=(
		port_discovery
		service_discovery
	)
steps_to_skip=False
steps_to_perform=False

# Function to display the script usage
display_usage() {
	while read -r line
	do
		printf "%b\n" "${line}"
	done <<-EOF
	\r USAGE:
	\r   ${script_file_name} [OPTIONS]

	\r Options:
	\r   -t,  --target \t target to enumerate
	\r   -w,  --workflow \t port scanning workflow [nmap2nmap|naabu2nmap|masscan2nmap]
	\r                   \t (default: ${underline}${port_scan_workflow}${reset})
	\r   -oD, --output-dir \t output directory path
	\r                 \t (default: ${underline}${output_directory}${reset})
	\r   -p,  --perform \t comma(,) separated list of steps to perform
	\r   -s,  --skip \t\t comma(,) separated list of steps to skip
	\r        --setup \t setup requirements for this script
	\r   -h,  --help \t\t display this help message and exit

	\r Available Steps:

	\r [+] port_discovery \t discover open ports
	\r [+] service_discovery \t discover running services & their versions

	\r ${red}${bold}HAPPY HACKING ${yellow}:)${reset}

EOF
}

# Function to handle open ports discovery
port_discovery() {
	[ "${skip}" == False ] && {
		echo -e "\n    [+] open port(s) discovery\n"

		# nmap2nmap workflow
		if [ "${port_scan_workflow}" == "nmap2nmap" ]
		then
			nmap -Pn -sS -T4 -n --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p0- ${target} -oA ${nmap_port_discovery_output}

			if [ ! -f ${nmap_port_discovery_output}.xml ]
			then 
				skip=True
			fi
		fi

		# naabu2nmap workflow
		if [ "${port_scan_workflow}" == "naabu2nmap" ]
		then
			${HOME}/go/bin/naabu -host ${target} -p - -silent | tee ${naabu_port_discovery_output}

			if [ $(wc -l < ${naabu_port_discovery_output}) -eq 0 ]
			then 
				skip=True

				echo -e "        [-] no open port discovered!"

				rm -rf ${port_discovery_output_dir}
			fi
		fi
	}
}

# Function to handle running services discovery and versions
service_discovery() {
	[ "${skip}" == False ] && {
		# nmap2nmap workflow
		if [ "${port_scan_workflow}" == "nmap2nmap" ]
		then
			if [ ! -f "${nmap_port_discovery_output}.xml" ]
			then
				port_discovery
			fi

			open_ports_space_separeted="$(xmllint --xpath '//port/state[@state = "open" or @state = "closed" or @state = "unfiltered"]/../@portid' ${nmap_port_discovery_output}.xml | awk -F\" '{ print $2 }' | tr '\n' ' ' |sed -e 's/[[:space:]]*$//')"

			if [ ${#open_ports_space_separeted} -gt 0 ]
			then
				echo -e "\n    [+] service(s) discovery\n"

				open_ports_comma_separeted=${open_ports_space_separeted// /,}

				nmap -Pn -sS -sV -T4 -n -p ${open_ports_comma_separeted} ${target} -oA ${service_discovery_output}
			fi
		fi

		# naabu2nmap workflow
		if [ "${port_scan_workflow}" == "naabu2nmap" ]
		then
			if [ ! -f ${naabu_port_discovery_output} ]
			then
				port_discovery
			fi

			echo -e "\n    [+] service(s) discovery\n"

			if [ ! -d ${service_discovery_output_dir} ]
			then
				mkdir -p ${service_discovery_output_dir}
			fi

			ports_dictionary=()

			while IFS=: read ip port
			do
				if [[ ! "${ports_dictionary[@]}" =~ "${port}" ]]
				then
					ports_dictionary+=(${port})
				fi
			done <<<$(cat ${naabu_port_discovery_output})

			if [ ${#ports_dictionary[@]} -gt 0 ]
			then
				ports_string="${ports_dictionary[@]}"

				nmap -Pn -sS -sV -T4 -n -p ${ports_string// /,} ${target} -oA ${service_discovery_output}
			fi
		fi
	}
}

# display banner
echo -e ${blue}${bold}"
                  _
  _ __  ___   ___| |__
 | '_ \/ __| / __| '_ \\
 | |_) \__  ${red}_${blue}\__ \ | | |
 | .__/|___${red}(_)${blue}___/_| |_| ${yellow}v1.0.0${blue}
 |_|
"${reset}

# parse options
while [[ "${#}" -gt 0 && ."${1}" == .-* ]]
do
	case ${1}  in
		-t | --target)
			target=${2}
			shift
		;;
		-w | --workflow)
			if [[ ! " ${port_scan_workflows[@]} " =~ " ${2} " ]]
			then
				echo -e "${blue}[${red}-${blue}]${reset} failed! unknown workflow: ${2}"
				exit 1
			fi
			port_scan_workflow=${2}
			shift
		;;
		-oD | --output-dir)
			output_directory="${2}"
			shift
		;;
		-p | --perform)
			steps_to_perform=${2}
			steps_to_perform_dictionary=${steps_to_perform//,/ }

			for i in ${steps_to_perform_dictionary}
			do
				if [[ ! " ${steps[@]} " =~ " ${i} " ]]
				then
					echo -e "${blue}[${red}-${blue}]${reset} failed! unknown step: ${i}"
					exit 1
				fi
			done
			shift
		;;
		-s | --skip)
			steps_to_skip=${2}
			steps_to_skip_dictionary=${steps_to_skip//,/ }

			for i in ${steps_to_skip_dictionary}
			do
				if [[ ! " ${steps[@]} " =~ " ${i} " ]]
				then
					echo -e "${blue}[${red}-${blue}]${reset} failed! unknown step: ${i}"
					exit 1
				fi
			done
			shift
		;;
		--setup)
			curl -sL https://raw.githubusercontent.com/enenumxela/ps.sh/main/install.sh | bash -
			exit 0
		;;
		-h | --help)
			display_usage
			exit 0
		;;
		*)
			display_usage
			exit 1
		;;
	esac
	shift
done

if [ "${UID}" -gt 0 ]
then
	echo -e "${blue}[${red}-${blue}]${reset} root privileges required!\n"
	exit 1
fi

# ensure target(s) is/are provided
if [ ${target} == False ] && [ ${targets_list} == False ]
then
	echo -e "${blue}[${red}-${blue}]${reset} failed! argument -t/--target OR -tL/--targets_list is Required!\n"
	exit 1
fi

# Flow for a single target
if [ ${target} != False ]
then
	echo -e "[*] port scanning ${target}"

	skip=False

	if [ ! -d ${output_directory} ]
	then
		mkdir -p ${output_directory}
	fi

	nmap_port_discovery_output="${output_directory}/${target}-nmap-port-discovery"
	naabu_port_discovery_output="${output_directory}/${target}-naabu-port-discovery.txt"

	service_discovery_output="${output_directory}/${target}-nmap-service-discovery"

	[ ${steps_to_perform} == False ] && [ ${steps_to_skip} == False ] && {
		for task in "${steps[@]}"
		do
			${task}
		done
	} || {
		[ ${steps_to_perform} != False ] && {
			for task in "${steps_to_perform_dictionary[@]}"
			do 
				${task}
			done
		}
		[ ${steps_to_skip} != False ] && {
			for task in ${steps[@]}
			do
				if [[ " ${steps_to_skip_dictionary[@]} " =~ " ${task} " ]]
				then
					continue
				else
					${task}
				fi
			done
		}
	}

	skip=False
fi

exit 0