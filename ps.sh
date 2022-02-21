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

keep=False
target=False
target_list=False
output_directory="."
port_scan_workflows=(
	nmap2nmap
	naabu2nmap
	masscan2nmap
)
port_scan_workflow="nmap2nmap"

display_banner() {
echo -e ${blue}${bold}"
                 _
 _ __  ___   ___| |__
| '_ \/ __| / __| '_ \\
| |_) \__  ${red}_${blue}\__ \ | | |
| .__/|___${red}(_)${blue}___/_| |_| ${yellow}v1.0.0${blue}
|_|"${reset}
}

display_usage() {
	display_banner

	while read -r line
	do
		printf "%b\n" "${line}"
	done <<-EOF
	\r USAGE:
	\r   ${script_file_name} [OPTIONS]

	\r Options:
	\r   -t, --target \t target IP or domain
	\r  -tL, --target_list \t target list IP or domain
	\r   -w, --workflow \t port scanning workflow (default: ${underline}${port_scan_workflow}${reset})
	\r                  \t (choices: nmap2nmap, naabu2nmap or masscan2nmap)
	\r   -k, --keep \t\t keep each workflow's step results
	\r  -oD, --output-dir \t output directory path (default: ${underline}${output_directory}${reset})
	\r       --setup \t\t install/update this script & depedencies
	\r   -h, --help \t\t display this help message and exit

	\r ${red}${bold}HAPPY HACKING ${yellow}:)${reset}

EOF
}

while [[ "${#}" -gt 0 && ."${1}" == .-* ]]
do
	case ${1}  in
		-t | --target)
			target=${2}
			shift
		;;
		-tL | --target_list)
			target_list=${2}

			if [ ! -f ${target_list} ] || [ ! -s ${target_list} ]
			then
				echo -e "${blue}[${red}-${blue}]${reset} failed!...Missing or Empty target list specified!"
				exit 1
			fi

			shift
		;;
		-w | --workflow)
			if [[ ! " ${port_scan_workflows[@]} " =~ " ${2} " ]]
			then
				echo -e " ${blue}[${red}-${blue}]${reset} failed!...unknown workflow: ${2}"
				exit 1
			fi
			port_scan_workflow=${2}
			shift
		;;
		-oD | --output-dir)
			output_directory="${2}"
			shift
		;;
		-k | --keep)
			keep=True
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

display_banner

if [ ${target} == False ] && [ ${target_list} == False ] 
then
	echo -e "${blue}[${red}-${blue}]${reset} failed!...Missing -t/--target or -tL/--target_list argument!\n"
	exit 1
fi

if [ ! -d ${output_directory} ]
then
	mkdir -p ${output_directory}
fi

per_target_workflow() {
	echo -e "\n${blue}[${green}+${blue}]${reset} TARGET: ${underline}${target}${reset}\n"

	# STEP 1: open port discovery
	echo -e "    ${blue}[${green}+${blue}]${reset} open port(s) discovery\n"

	open_ports=()
	open_ports_discovery_output=""

	if [ "${port_scan_workflow}" == "nmap2nmap" ]
	then
		open_ports_discovery_output="${output_directory}/${target}-nmap-port-discovery.xml"

		if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
		then
			sudo nmap -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p0- ${target} -Pn -oX ${open_ports_discovery_output}
		else
			echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped!...previous results found!"
		fi
	fi

	if [ "${port_scan_workflow}" == "naabu2nmap" ]
	then
		open_ports_discovery_output="${output_directory}/${target}-naabu-port-discovery.txt"

		if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
		then
			sudo ${HOME}/go/bin/naabu -host ${target} -p 1-65535 -o ${open_ports_discovery_output}
		else
			echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped!...previous results found!"
		fi
	fi

	if [ "${port_scan_workflow}" == "masscan2nmap" ]
	then
		open_ports_discovery_output="${output_directory}/${target}-masscan-port-discovery.xml"

		if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
		then
			sudo masscan --ports 0-65535 ${target} --max-rate 1000 -oX ${open_ports_discovery_output}
		else
			echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped...previous results found!"
		fi
	fi

	# SETP 2: extract open ports from open port discovery output
	if [ -f ${open_ports_discovery_output} ] && [ -s ${open_ports_discovery_output} ]
	then
		if [ "${port_scan_workflow}" == "masscan2nmap" ] || [ "${port_scan_workflow}" == "nmap2nmap" ]
		then
			open_ports="$(xmllint --xpath '//port/state[@state = "open" or @state = "closed" or @state = "unfiltered"]/../@portid' ${open_ports_discovery_output} | awk -F\" '{ print $2 }' | tr '\n' ' ' |sed -e 's/[[:space:]]*$//')"
		elif [ "${port_scan_workflow}" == "naabu2nmap" ]
		then
			while IFS=: read ip port
			do
				if [[ ! "${open_ports[@]}" =~ "${port}" ]]
				then
					open_ports+=(${port})
				fi
			done <<<$(cat ${open_ports_discovery_output})
		fi
		
	fi

	# SETP 3: service discovery
	echo -e "\n    ${blue}[${green}+${blue}]${reset} service(s) discovery\n"

	service_discovery_output="${output_directory}/${target}"

	if [ ${#open_ports} -le 0 ]
	then
		skip=True

		echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped!...no open ports discovered!"

		rm -rf ${nmap_port_discovery_output}
	else
		sudo nmap -T4 -A -p ${open_ports// /,} ${target} -Pn -oA ${service_discovery_output}
	fi

	if [ ${keep} == False ]
	then
		rm -rf ${output_directory}/*-port-discovery.*
	fi
}

if [ ${target} != False ]
then
	per_target_workflow
elif [ ${target_list} != False ]
then
	for target in $(cat ${target_list}| sort -u)
	do
		per_target_workflow
	done
fi

exit 0