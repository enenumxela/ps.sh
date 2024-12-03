#!/usr/bin/env bash

set -e

declare -A format=(
	[color_blue]="\e[34m"
	[color_cyan]="\e[36m"
	[color_green]="\e[32m"
	[color_red]="\e[31m"
	[color_yellow]="\e[33m"
	[bold]="\e[1m"
	[underline]="\e[4m"
	[reset]="\e[0m"
)

CMD_PREFIX=

if [ ${UID} -gt 0 ] && [ -x "$(command -v sudo)" ]
then
	CMD_PREFIX="sudo"
elif [ ${UID} -gt 0 ] && [ ! -x "$(command -v sudo)" ]
then
	echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...\`sudo\` not found!\n"

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
	echo "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} Could not find wget/cURL\n" >&2

	exit 1
fi

# --- FUNCTIONS ---------------------------------------------------------------------------------------------------------

# Function to display the script's banner.
display_script_banner() {
echo -e ${format[bold]}${format[color_blue]}"
                                          _
                          _ __  ___   ___| |__
                         | '_ \/ __| / __| '_ \\
                         | |_) \__  ${format[color_red]}_${format[color_blue]}\__ \ | | |
                         | .__/|___${format[color_red]}(_)${format[color_blue]}___/_| |_|
                         |_|              ${format[color_red]}v1.0.0${format[color_green]}

              ---====| ${format[color_blue]}A Service Discovery Script${format[color_green]} |====---
                      ---====| ${format[color_blue]}with <3...${format[color_green]} |====---
               ---====| ${format[color_blue]}...by Alex (${format[color_red]}@enenumxela${format[color_blue]})${format[color_green]} |====---
"${format[reset]}
}

display_script_usage() {
	while read -r line
	do
		printf "%b\n" "${line}"
	done <<-EOF
	\rUSAGE:
	\r  ${0##*/} [OPTIONS]

	\rOPTIONS:

	\r INPUT:
	\r  -t, --target \t\t\t target IP
	\r  -l, --list \t\t\t\t target IPs list file

	\r WORKFLOW:
	\r  -w, --workflow \t\t discovery workflow (default: ${format[underline]}${workflow}${format[reset]})
	\r      --workflows \t\t list supported workflows

	\r OUPUT:
	\r  -k, --keep \t\t\t\t keep each workflow's step results
	\r  -O, --output-directory \t output directory path (default: \$PWD)

	\r SETUP:
	\r      --setup-script \t\t setup ${0##*/} (install|update)
	\r      --setup-dependencies \t setup ${0##*/} dependencies

	\r HELP:
	\r  -h, --help \t\t\t\t display this help message

EOF
}

setup_script() {
	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Setting up script...started!\n"

	script_directory="${HOME}/.local/bin"

	if [ ! -d ${script_directory} ]
	then
		mkdir -p ${script_directory}
	fi

	script_path="${script_directory}/ps.sh"

	if [ -e "${script_path}" ]
	then
		rm ${script_path}
	fi

	eval ${DOWNLOAD_CMD} https://raw.githubusercontent.com/enenumxela/ps.sh/main/ps.sh > ${script_path}

	if [ -f ${script_path} ]
	then
		chmod u+x ${script_path}
	fi

	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Setting up script...done!\n"
}

setup_depedencies() {
	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Setting up dependancies...started!\n"

	eval ${CMD_PREFIX} apt-get install -y -qq libxml2-utils libpcap-dev

	if [ ! -x "$(command -v nmap)" ]
	then
		eval ${CMD_PREFIX} apt-get install -y -qq nmap
	fi

	if [ ! -x "$(command -v naabu)" ]
	then
		eval ${DOWNLOAD_CMD} https://github.com/projectdiscovery/naabu/releases/download/v2.3.3/naabu_2.3.3_linux_amd64.zip >> /tmp/naabu.zip

		if [ -f /tmp/naabu.zip ]
		then
			unzip /tmp/naabu.zip -d /tmp && ${CMD_PREFIX} mv /tmp/naabu /usr/local/bin/
		fi
	fi

	if [ ! -x "$(command -v masscan)" ]
	then
		eval ${CMD_PREFIX} apt-get install -y -qq masscan
	fi

	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Setting up dependancies...done!\n"
}

valid_ip() {
	local  IP=$1
	local  stat=1

	if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
	then
		OIFS=$IFS
		IFS='.'
		IP=($IP)
		IFS=$OIFS
		[[ ${IP[0]} -le 255 && ${IP[1]} -le 255 \
			&& ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
		stat=$?
	fi

	return $stat # Return 0 if valid, 1 if not.
}

# Function to perform port scanning on a single target.
# Arguments:
#   $1 - IP address of the target.
#   $2 - Workflow to use for port scanning.
port_scan() {
	if valid_ip $1
	then
		echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Discovery for ${format[bold]}${format[underline]}${1}${format[reset]}...started!\n"

		local open_ports=()

		local open_ports_discovery_output=""
		local open_ports_service_discovery_output="${output_directory}/${1}"

		# Skip scanning if results already exist.
		if [ ! -f ${open_ports_service_discovery_output}.xml ] || [ ! -s ${open_ports_service_discovery_output}.xml ]
		then
			echo -e "    ${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Open Port(s) Discovery\n"

			if [ "${2}" == "nmap2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${1}-nmap-port-discovery.xml"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} nmap -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p 0-65535 ${1} -Pn -oX ${open_ports_discovery_output}
				else
					echo -e "        ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped!...previous results found!"
				fi
			fi

			if [ "${2}" == "naabu2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${1}-naabu-port-discovery.txt"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} ${HOME}/go/bin/naabu -host ${1} -p 0-65535 -Pn -o ${open_ports_discovery_output}
				else
					echo -e "        ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped!...previous results found!"
				fi
			fi

			if [ "${2}" == "masscan2nmap" ]
			then
				open_ports_discovery_output="${output_directory}/${1}-masscan-port-discovery.xml"

				if [ ! -f ${open_ports_discovery_output} ] || [ ! -s ${open_ports_discovery_output} ]
				then
					eval ${CMD_PREFIX} masscan --ports 0-65535 ${1} --max-rate 1000 -oX ${open_ports_discovery_output}
				else
					echo -e "        ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped...previous results found!"
				fi
			fi

			if [ -f ${open_ports_discovery_output} ] && [ -s ${open_ports_discovery_output} ]
			then
				if [ "${2}" == "nmap2nmap" ] || [ "${2}" == "masscan2nmap" ]
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

			echo -e "\n    ${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Service(s) Discovery\n"

			if [ ${#open_ports} -le 0 ]
			then
				echo -e "        ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped!...no open ports discovered!"

				rm -rf ${nmap_port_discovery_output}
			else
				eval ${CMD_PREFIX} nmap -T4 -A -p ${open_ports// /,} ${1} -Pn -oA ${open_ports_service_discovery_output}
			fi
		else
			echo -e "    ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped!...previous results found!"
		fi

		if [ -f ${open_ports_discovery_output} ] && [ ${keep} == False ]
		then
			rm -rf ${open_ports_discovery_output}
		fi

		echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Discovery for ${format[bold]}${format[underline]}${1}${format[reset]}...done!\n"
	else
		echo -e "\n${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped!...${format[underline]}${target}${format[reset]} is not/invalid IP Address!\n"
	fi
}

# --- MAIN --------------------------------------------------------------------------------------------------------------

display_script_banner

if [[ -z ${@} ]]
then
	display_script_usage

	exit 0
fi

if [ "${SUDO_USER:-$USER}" != "${USER}" ]
then
	echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...ps.sh shouldn't be called with sudo!\n"
	
	exit 1
fi

target=False
target_list=False
workflow="nmap2nmap"
workflow_list=(
	nmap2nmap
	naabu2nmap
	masscan2nmap
)
output_directory="${PWD}"
keep=False

while [[ "${#}" -gt 0 && ."${1}" == .-* ]]
do
	case ${1}  in
		-t | --target)
			target=${2}

			shift
		;;
		-l | --list)
			target_list=${2}

			if [ ! -f ${target_list} ] || [ ! -s ${target_list} ]
			then
				echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...Missing or Empty target list specified!\n"

				exit 1
			fi

			shift
		;;
		-w | --workflow)
			if [[ ! " ${workflow_list[@]} " =~ " ${2} " ]]
			then
				echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...unknown workflow: ${2}\n"

				exit 1
			fi

			workflow=${2}

			shift
		;;
		--workflows)
			echo -e "Supported workflows:"

			echo
			for workflow in ${workflow_list[@]}
			do
				echo -e " ${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} ${workflow}"
			done
			echo

			exit 0
		;;
		-k | --keep)
			keep=True
		;;
		-O | --output-directory)
			output_directory="${2}"

			shift
		;;
		--setup-script)
			setup_script

			exit 0
		;;
		--setup-depedencies)
			setup_depedencies

			exit 0
		;;
		-h | --help)
			display_script_usage

			exit 0
		;;
		*)
			display_script_usage

			exit 1
		;;
	esac

	shift
done

if [ ${target} == False ] && [ ${target_list} == False ] 
then
	echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...Missing -t/--target or -tL/--target_list argument!\n"

	exit 1
fi

if [ ! -d ${output_directory} ]
then
	mkdir -p ${output_directory}
fi

if [ ${target} != False ]
then
	port_scan $target $workflow
elif [ ${target_list} != False ]
then
	for target in $(cat ${target_list} | sort -u)
	do
		port_scan $target $workflow
	done
fi

exit 0