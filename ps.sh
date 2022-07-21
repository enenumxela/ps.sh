#!/usr/bin/env bash

set -e

script_file_name=${0##*/}

RED="\e[31m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"

BOLD="\e[1m"
UNDERLINE="\e[4m"
RESET="\e[0m"

target=False
target_list=False

keep=False
output_directory="."

port_scan_workflows=(
	nmap2nmap
	naabu2nmap
	masscan2nmap
)
port_scan_workflow="nmap2nmap"

CMD_PREFIX=

if [ ${UID} -gt 0 ] && [ -x "$(command -v sudo)" ]
then
	CMD_PREFIX="sudo"
elif [ ${UID} -gt 0 ] && [ ! -x "$(command -v sudo)" ]
then
	echo -e "\n${BLUE}[${RED}-${BLUE}]${RESET} failed!...\`sudo\` command not found!\n"
	exit 1
fi

DOWNLOAD_CMD=

if command -v >&- curl
then
	DOWNLOAD_CMD="curl -sL"
elif command -v >&- wget
then
	DOWNLOAD_CMD="wget --quiet --show-progres --continue --output-document=-"
else
	echo "\n${BLUE}[${RED}-${BLUE}]${RESET} Could not find wget/cURL\n" >&2
	exit 1
fi

display_banner() {
echo -e ${BLUE}${BOLD}"
                 _
 _ __  ___   ___| |__
| '_ \/ __| / __| '_ \\
| |_) \__  ${RED}_${BLUE}\__ \ | | |
| .__/|___${RED}(_)${BLUE}___/_| |_| ${YELLOW}v1.0.0${BLUE}
|_|"${RESET}
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
	\r -tL, --target-list \t target IPs list
	\r  -w, --workflow \t port scanning workflow (default: ${UNDERLINE}${port_scan_workflow}${RESET})
	\r                 \t (choices: nmap2nmap, naabu2nmap or masscan2nmap)
	\r  -k, --keep \t\t keep each workflow's step results
	\r -oD, --output-dir \t output directory path (default: ${UNDERLINE}${output_directory}${RESET})
	\r      --update \t\t update this script & dependencies
	\r  -h, --help \t\t display this help message and exit

	\r${RED}${BOLD}HAPPY HACKING ${YELLOW}:)${RESET}

EOF
}

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

# handle a single target port scanning workflow
port_scan() {
	if valid_ip $1
	then
		echo -e "\n${BLUE}[${GREEN}+${BLUE}]${RESET} TARGET: ${UNDERLINE}${1}${RESET}\n"

		local open_ports=()

		local open_ports_discovery_output=""
		local open_ports_service_discovery_output="${output_directory}/${1}"

		if [ ! -f ${open_ports_service_discovery_output}.xml ] || [ ! -s ${open_ports_service_discovery_output}.xml ]
		then
			# STEP 1: open port discovery
			echo -e "    ${BLUE}[${GREEN}+${BLUE}]${RESET} open port(s) discovery\n"

			if [ "${2}" == "nmap2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${1}-nmap-port-discovery.xml"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} nmap -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p 0-65535 ${1} -Pn -oX ${open_ports_discovery_output}
				else
					echo -e "        ${BLUE}[${YELLOW}*${BLUE}]${RESET} skipped!...previous results found!"
				fi
			fi

			if [ "${2}" == "naabu2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${1}-naabu-port-discovery.txt"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} ${HOME}/go/bin/naabu -host ${1} -p 0-65535 -o ${open_ports_discovery_output}
				else
					echo -e "        ${BLUE}[${YELLOW}*${BLUE}]${RESET} skipped!...previous results found!"
				fi
			fi

			if [ "${2}" == "masscan2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${1}-masscan-port-discovery.xml"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} masscan --ports 0-65535 ${1} --max-rate 1000 -oX ${open_ports_discovery_output}
				else
					echo -e "        ${BLUE}[${YELLOW}*${BLUE}]${RESET} skipped...previous results found!"
				fi
			fi

			# SETP 2: extract open ports from open port discovery output
			if [ -f ${open_ports_discovery_output} ] && [ -s ${open_ports_discovery_output} ]
			then
				if [ "${2}" == "masscan2nmap" ] || [ "${2}" == "nmap2nmap" ]
				then
					open_ports="$(xmllint --xpath '//port/state[@state = "open" or @state = "closed" or @state = "unfiltered"]/../@portid' ${open_ports_discovery_output} | awk -F\" '{ print $2 }' | tr '\n' ' ' |sed -e 's/[[:space:]]*$//')"
				elif [ "${2}" == "naabu2nmap" ]
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
			echo -e "\n    ${BLUE}[${GREEN}+${BLUE}]${RESET} service(s) discovery\n"

			if [ ${#open_ports} -le 0 ]
			then
				echo -e "        ${BLUE}[${YELLOW}*${BLUE}]${RESET} skipped!...no open ports discovered!"

				rm -rf ${nmap_port_discovery_output}
			else
				eval ${CMD_PREFIX} nmap -T4 -A -p ${open_ports// /,} ${1} -Pn -oA ${open_ports_service_discovery_output}
			fi

			if [ ${keep} == False ]
			then
				rm -rf ${output_directory}/*-port-discovery.*
			fi
		else
			echo -e "    ${BLUE}[${YELLOW}*${BLUE}]${RESET} skipped!...previous results found!"
		fi
	else
		echo -e "\n${BLUE}[${YELLOW}*${BLUE}]${RESET} skipped!...${UNDERLINE}${target}${RESET} is not/invalid IP Address!\n"
	fi
}

# check then fail if script is called with sudo
if [ "${SUDO_USER:-$USER}" != "${USER}" ]
then
	echo -e "\n${BLUE}[${RED}-${BLUE}]${RESET} failed!...ps.sh called with sudo!\n"
	exit 1
fi

# parse command line arguments
while [[ "${#}" -gt 0 && ."${1}" == .-* ]]
do
	case ${1}  in
		-t | --target)
			target=${2}
			shift
		;;
		-tL | --target-list)
			target_list=${2}

			if [ ! -f ${target_list} ] || [ ! -s ${target_list} ]
			then
				echo -e "\n${BLUE}[${RED}-${BLUE}]${RESET} failed!...Missing or Empty target list specified!\n"
				exit 1
			fi

			shift
		;;
		-w | --workflow)
			if [[ ! " ${port_scan_workflows[@]} " =~ " ${2} " ]]
			then
				echo -e "\n${BLUE}[${RED}-${BLUE}]${RESET} failed!...unknown workflow: ${2}\n"
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
		--update)
			eval ${DOWNLOAD_CMD} https://raw.githubusercontent.com/hueristiq/ps.sh/main/install.sh | bash -
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

# check then fail if both target and target list are missing
if [ ${target} == False ] && [ ${target_list} == False ] 
then
	echo -e "\n${BLUE}[${RED}-${BLUE}]${RESET} failed!...Missing -t/--target or -tL/--target_list argument!\n"
	exit 1
fi

# display the banner
display_banner

# make output directory if it doesn't exist
if [ ! -d ${output_directory} ]
then
	mkdir -p ${output_directory}
fi

# handle the main workflow
if [ ${target} != False ]
then
	port_scan $target $port_scan_workflow
elif [ ${target_list} != False ]
then
	for target in $(cat ${target_list}| sort -u)
	do
		port_scan $target $port_scan_workflow
	done
fi

exit 0