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

banner() {
echo -e ${format[bold]}${format[color_blue]}"
                                          _
                          _ __  ___   ___| |__
                         | '_ \/ __| / __| '_ \\
                         | |_) \__  ${format[color_red]}_${format[color_blue]}\__ \ | | |
                         | .__/|___${format[color_red]}(_)${format[color_blue]}___/_| |_|
                         |_|              ${format[color_red]}v1.0.0${format[color_green]}

              ---====| ${format[color_blue]}A Service Discovery Script.${format[color_green]} |====---
"${format[reset]}
}

usage() {
	while read -r line
	do
		printf "%b\n" "${line}"
	done <<-EOF
	\rUSAGE:
	\r  ${0##*/} [OPTIONS]

	\rOPTIONS:
	\r  -t, --target \t\t\t target IP
	\r  -l, --list \t\t\t target IPs list file

	\r WORKFLOW:
	\r  -w, --workflow \t\t discovery workflow (default: ${format[underline]}${workflow}${format[reset]})
	\r      --workflows \t\t supported discovery workflows

	\r OUPUT:
	\r  -O, --output-directory \t output directory path (default: \$PWD)

	\r SETUP:
	\r      --setup \t\t\t setup ${0##*/} dependencies

	\r HELP:
	\r  -h, --help \t\t\t display this help message

EOF
}

setup() {
	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Setup...started!\n"

	eval ${CMD_PREFIX} apt-get install -y -qq libxml2-utils

	if [ ! -x "$(command -v nmap)" ]
	then
		eval ${CMD_PREFIX} apt-get install -y -qq nmap
	fi

	if [ ! -x "$(command -v masscan)" ]
	then
		eval ${CMD_PREFIX} apt-get install -y -qq masscan
	fi

	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Setup...done!\n"
}

is_a_valid_IP() {
	local IP=$1
	local stat=1

	if [[ $IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
	then
		OIFS=$IFS
		IFS='.'
		IP=($IP)
		IFS=$OIFS
		[[ ${IP[0]} -le 255 && ${IP[1]} -le 255 && ${IP[2]} -le 255 && ${IP[3]} -le 255 ]]
		stat=$?
	fi

	return $stat
}

discover() {
	local target=$1
	local workflow=$2

	if ! is_a_valid_IP "$target"
	then
		echo -e "\n${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped!...${target} is not a valid IP Address!\n"

		return 1
	fi

	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Discovery for ${format[bold]}${format[underline]}${target}${format[reset]}...started!\n"

	local open_ports=()

	local port_s_discovery_output=""
	local service_s_discovery_output="${output_directory}/${target}"

	echo -e " ${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Port(s) Discovery"

	case "${workflow}" in
		nmap2nmap)
			port_s_discovery_output="${output_directory}/${target}-nmap-port-discovery.xml"

			if [[ ! -s "${port_s_discovery_output}" ]]
			then
				${CMD_PREFIX} nmap -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p- -Pn "${target}" -oX "${port_s_discovery_output}"
			else
				echo -e " ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped! Previous results found."
			fi

			if [[ -s "${port_s_discovery_output}" ]]
			then
				open_ports=($(xmllint --xpath '//port/state[@state="open"]/../@portid' "${port_s_discovery_output}" 2>/dev/null | awk -F'"' '{print $2}'))
			fi
			;;
		masscan2nmap)
			port_s_discovery_output="${output_directory}/${target}-masscan-port-discovery.xml"

			if [[ ! -s "${port_s_discovery_output}" ]]
			then
				${CMD_PREFIX} masscan --ports 0-65535 "${target}" --max-rate 1000 -oX "${port_s_discovery_output}"
			else
				echo -e " ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped! Previous results found."
			fi

			if [[ -s "${port_s_discovery_output}" ]]
			then
				open_ports=($(xmllint --xpath '//port/state[@state="open"]/../@portid' "${port_s_discovery_output}" 2>/dev/null | awk -F'"' '{print $2}'))
			fi
			;;
	esac

	echo -e "\n ${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Service(s) Discovery"

	if [[ ${#ports[@]} -eq 0 ]]
	then
		echo -e " ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} No open ports found."
	else
		open_ports=($(printf '%s\n' "${open_ports[@]}" | sort -nu))

		local open_ports_list=$(IFS=,; echo "${open_ports[*]}")

		if [[ ! -s "${service_s_discovery_output}.xml" ]]
		then
			$CMD_PREFIX nmap -T4 -A -p "${open_ports_list}" "${target}" -Pn -oA "${service_s_discovery_output}"
		else
			echo -e " ${format[color_blue]}[${format[color_yellow]}*${format[color_blue]}]${format[reset]} skipped! Previous results found."
		fi
	fi

	echo -e "\n${format[color_blue]}[${format[color_green]}+${format[color_blue]}]${format[reset]} Discovery for ${format[bold]}${target}${format[reset]}...done!\n"
}

banner

target="False"
target_list="False"

workflow="nmap2nmap"
workflow_list=(
	nmap2nmap
	masscan2nmap
)

output_directory="${PWD}"

if [[ -z ${@} ]]
then
	usage

	exit 0
fi

if [ "${SUDO_USER:-$USER}" != "${USER}" ]
then
	echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...ps.sh shouldn't be called with sudo!\n"

	exit 1
fi

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
		-O | --output-directory)
			output_directory="${2}"

			shift
		;;
		--setup)
			setup

			exit 0
		;;
		-h | --help)
			usage

			exit 0
		;;
		*)
			usage

			exit 1
		;;
	esac

	shift
done

if [ ${target} == "False" ] && [ ${target_list} == "False" ] 
then
	echo -e "\n${format[color_blue]}[${format[color_red]}-${format[color_blue]}]${format[reset]} failed!...Missing -t/--target or -tL/--target_list argument!\n"

	exit 1
fi

if [ ! -d ${output_directory} ]
then
	mkdir -p ${output_directory}
fi

if [ ${target} != "False" ]
then
	discover "${target}" "${workflow}"
elif [ ${target_list} != "False" ]
then
	while read -r target
	do
		discover "${target}" "${workflow}"
	done < <(sort -u "${target_list}")
fi

exit 0