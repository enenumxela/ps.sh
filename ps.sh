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

	\rUSAGE:
	\r  ${script_file_name} [OPTIONS]

	\rOptions:
	\r  -t, --target \t\t target IP
	\r -tL, --target_list \t target IPs list
	\r  -w, --workflow \t port scanning workflow (default: ${underline}${port_scan_workflow}${reset})
	\r                 \t (choices: nmap2nmap, naabu2nmap or masscan2nmap)
	\r  -k, --keep \t\t keep each workflow's step results
	\r -oD, --output-dir \t output directory path (default: ${underline}${output_directory}${reset})
	\r      --setup \t\t install/update this script & dependencies
	\r  -h, --help \t\t display this help message and exit

	\r${red}${bold}HAPPY HACKING ${yellow}:)${reset}

EOF
}

DOWNLOAD_CMD=

if command -v >&- curl
then
	DOWNLOAD_CMD="curl --silent"
elif command -v >&- wget
then
	DOWNLOAD_CMD="wget --quiet --show-progres --continue --output-document=-"
else
	echo "[-] Could not find wget/cURL" >&2
	exit 1
fi

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
				echo -e "\n${blue}[${red}-${blue}]${reset} failed!...Missing or Empty target list specified!\n"
				exit 1
			fi

			shift
		;;
		-w | --workflow)
			if [[ ! " ${port_scan_workflows[@]} " =~ " ${2} " ]]
			then
				echo -e "\n${blue}[${red}-${blue}]${reset} failed!...unknown workflow: ${2}\n"
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
			eval ${DOWNLOAD_CMD} https://raw.githubusercontent.com/enenumxela/ps.sh/main/install.sh | bash -
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
	echo -e "\n${blue}[${red}-${blue}]${reset} failed!...Missing -t/--target or -tL/--target_list argument!\n"
	exit 1
fi

if [ "$(logname)" != "${USER}" ]
then
	echo -e "\n${blue}[${red}-${blue}]${reset} failed!...ps.sh called with sudo!\n"
	exit 1
fi

CMD_PREFIX=

if [ ${UID} -gt 0 ] && [ -x "$(command -v sudo)" ]
then
	CMD_PREFIX="sudo"
elif [ ${UID} -gt 0 ] && [ ! -x "$(command -v sudo)" ]
then
	echo -e "\n${blue}[${red}-${blue}]${reset} failed!...\`sudo\` command not found!\n"
	exit 1
fi

if [ ! -d ${output_directory} ]
then
	mkdir -p ${output_directory}
fi

valid_ip() {
	local  ip=$1
	local  stat=1

	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
	then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
			&& ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	fi

	return $stat
}

per_target_workflow() {
	if valid_ip $target
	then
		echo -e "\n${blue}[${green}+${blue}]${reset} TARGET: ${underline}${target}${reset}\n"

		open_ports=()
		open_ports_discovery_output=""
		service_discovery_output="${output_directory}/${target}"

		if [ ! -f ${service_discovery_output}.xml ] || [ ! -s ${service_discovery_output}.xml ]
		then
			# STEP 1: open port discovery
			echo -e "    ${blue}[${green}+${blue}]${reset} open port(s) discovery\n"

			if [ "${port_scan_workflow}" == "nmap2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${target}-nmap-port-discovery.xml"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} nmap -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p 0-65535 ${target} -Pn -oX ${open_ports_discovery_output}
				else
					echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped!...previous results found!"
				fi
			fi

			if [ "${port_scan_workflow}" == "naabu2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${target}-naabu-port-discovery.txt"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} ${HOME}/go/bin/naabu -host ${target} -p 0-65535 -o ${open_ports_discovery_output}
				else
					echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped!...previous results found!"
				fi
			fi

			if [ "${port_scan_workflow}" == "masscan2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${target}-masscan-port-discovery.xml"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} masscan --ports 0-65535 ${target} --max-rate 1000 -oX ${open_ports_discovery_output}
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

			if [ ${#open_ports} -le 0 ]
			then
				echo -e "        ${blue}[${yellow}*${blue}]${reset} skipped!...no open ports discovered!"

				rm -rf ${nmap_port_discovery_output}
			else
				eval ${CMD_PREFIX} nmap -T4 -A -p ${open_ports// /,} ${target} -Pn -oA ${service_discovery_output}
			fi

			if [ ${keep} == False ]
			then
				rm -rf ${output_directory}/*-port-discovery.*
			fi
		else
			echo -e "    ${blue}[${yellow}*${blue}]${reset} skipped!...previous results found!"
		fi
	else
		echo -e "\n${blue}[${yellow}*${blue}]${reset} skipped!...${underline}${target}${reset} is not/invalid IP Address!\n"
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