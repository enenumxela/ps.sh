#!/usr/bin/env bash

set -euo pipefail

declare -A fmt=(
	[blue]="\e[34m"
	[cyan]="\e[36m"
	[green]="\e[32m"
	[red]="\e[31m"
	[yellow]="\e[33m"
	[bold]="\e[1m"
	[underline]="\e[4m"
	[reset]="\e[0m"
)

CMD_PREFIX=

if [[ ${UID} -gt 0 ]]
then
	if command -v sudo &>/dev/null
	then
		CMD_PREFIX="sudo"
	else
		echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...running as root and \`sudo\` was not found.\n"

		exit 1
	fi
fi

banner() {
echo -e ${fmt[bold]}${fmt[blue]}"
                                                  _
                                  _ __  ___   ___| |__
                                 | '_ \/ __| / __| '_ \\
                                 | |_) \__  ${fmt[red]}_${fmt[blue]}\__ \ | | |
                                 | .__/|___${fmt[red]}(_)${fmt[blue]}___/_| |_|
                                 |_|              ${fmt[red]}v1.0.0${fmt[green]}

<>--------------------------<><> ${fmt[blue]}A Port Scanning Script.${fmt[green]} <><>--------------------------<>
"${fmt[reset]}
}

usage() {
	while IFS= read -r line; do
		printf "%b\n" "${line}"
	done <<-EOF
	\r USAGE:
	\r   ${0##*/} [OPTIONS]
	\r
	\r OPTIONS:
	\r   -t, --target              target IP
	\r   -l, --list                target IPs file
	\r   -p, --ports               target port(s) (default: ${fmt[underline]}${ports}${fmt[reset]})
	\r   -w, --workflow            discovery workflow (default: ${fmt[underline]}${workflow}${fmt[reset]})
	\r       --workflows           list supported discovery workflows
	\r   -o, --output              output directory (default: ${fmt[underline]}${output}${fmt[reset]})
	\r       --setup               install required dependencies
	\r   -h, --help                display this help
	\r
EOF
}

setup() {
	echo -e " ${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} Setting up...\n"

	local pkgs=()

	command -v nmap &>/dev/null || pkgs+=(nmap)
	command -v masscan &>/dev/null || pkgs+=(masscan)
	command -v xmllint &>/dev/null || pkgs+=(libxml2-utils)

	if [[ ${#pkgs[@]} -ne 0 ]]
	then
		$CMD_PREFIX apt-get update -qq
		$CMD_PREFIX apt-get install -y -qq "${pkgs[@]}"
	else
		echo -e "    ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...all is set."
	fi

	echo -e "\n ${fmt[blue]}[${fmt[green]}✓${fmt[blue]}]${fmt[reset]} Setting up...done!\n"
}

is_valid_IP() {
	local IP="$1"

	if ! [[ "${IP}" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]
	then 
		return 1
	fi

	local octet

	for octet in "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
	do
		if ! (( octet <= 255 ))
		then
			return 1
		fi
	done

	return 0
}

run_nmap_open_ports_discovery() {
	local nmap_target="$1"
	local nmap_ports="$2"
	local nmap_output="$3"

	${CMD_PREFIX} nmap --min-rate 1000 -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p "${nmap_ports}" -Pn "${nmap_target}" -oX "${nmap_output}"
}

run_masscan_open_ports_discovery() {
	local masscan_target="$1"
	local masscan_ports="$2"
	local masscan_output="$3"

	${CMD_PREFIX} masscan --ports "${masscan_ports}" "${masscan_target}" --max-rate 1000 -oX "${masscan_output}"
}

xml_extract_open_ports() {
	local xml_file="$1"

	xmllint --xpath '//port/state[@state="open"]/../@portid' "${xml_file}" 2>/dev/null | grep -oP '"\K[^"]+' | sort -nu
}

discover() {
	local target=$1
	local ports=$2
	local workflow=$3

	if ! is_valid_IP "$target"
	then
		echo -e "${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...invalid IP \"${target}\".\n"

		return 0
	fi

	echo -e "${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} Scanning ${fmt[bold]}${fmt[underline]}${target}${fmt[reset]}...\n"

	local -a open_ports=()

	local port_s_discovery_output=""
	local service_s_discovery_output="${output}/${target}"

	echo -e "    ${fmt[blue]}[${fmt[green]}>${fmt[blue]}]${fmt[reset]} Port(s) Discovery\n"

	case "${workflow}" in
		nmap2nmap)
			port_s_discovery_output="${output}/${target}-nmap-port-discovery.xml"

			if [[ -s "${port_s_discovery_output}" ]]
			then
				echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found."
			else
				run_nmap_open_ports_discovery "${target}" "${ports}" "${port_s_discovery_output}"
			fi

			if [[ -s "${port_s_discovery_output}" ]]
			then
				mapfile -t open_ports < <(xml_extract_open_ports "${port_s_discovery_output}")
			fi
			;;
		masscan2nmap)
			port_s_discovery_output="${output}/${target}-masscan-port-discovery.xml"

			if [[ -s "${port_s_discovery_output}" ]]
			then
				echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found."
			else
				run_masscan_open_ports_discovery "${target}" "${ports}" "${port_s_discovery_output}"
			fi

			if [[ -s "${port_s_discovery_output}" ]]
			then
				mapfile -t open_ports < <(xml_extract_open_ports "${port_s_discovery_output}")
			fi
			;;
	esac

	echo -e "\n    ${fmt[blue]}[${fmt[green]}>${fmt[blue]}]${fmt[reset]} Service(s) Discovery\n"

	if [[ ! -s "${service_s_discovery_output}.xml" ]]
	then
		if [[ ${#open_ports[@]} -eq 0 ]]
		then
			echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...no open ports found."
		else
			mapfile -t open_ports < <(printf '%s\n' "${open_ports[@]}" | sort -nu)

			local open_ports_csv

			open_ports_csv="$(IFS=','; printf '%s' "${open_ports[*]}")"

			$CMD_PREFIX nmap -T4 -A --max-retries 2 -p "${open_ports_csv}" -Pn "${target}" -oA "${service_s_discovery_output}"
		fi
	else
		echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found."
	fi

	echo -e "\n${fmt[blue]}[${fmt[green]}✓${fmt[blue]}]${fmt[reset]} Scanning ${fmt[bold]}${fmt[underline]}${target}${fmt[reset]}...done!\n"
}

readonly workflows=(
	nmap2nmap
	masscan2nmap
)

target="__none__"
target_list="__none__"

ports="0-65535"

workflow="nmap2nmap"

output="${PWD}"

banner

if [[ $# -eq 0 ]]
then
	usage

	exit 0
fi

if [[ -n "${SUDO_USER:-}" ]]
then
	echo -e "\n${fmt[blue]}[${fmt[color_red]}✗${fmt[blue]}]${fmt[reset]} failed!...${0##*/} shouldn't be run with sudo, it escalates privileges internally when needed.\n"

	exit 1
fi

while [[ $# -gt 0 && "$1" == -* ]]
do
	case ${1} in
		-t | --target)
			target="${2:?'-t/--target requires an argument.'}"

			shift
		;;
		-l | --list)
			target_list="${2:?'-l/--list requires an argument.'}"

			if [[ ! -f "$target_list" || ! -s "$target_list" ]]
			then
				echo -e "\n${fmt[blue]}[${fmt[color_red]}✗${fmt[blue]}]${fmt[reset]} failed!...missing or empty IPs file.\n"

				exit 1
			fi

			shift
		;;
		-p | --ports)
			ports="${2:?'-p/--ports requires an argument.'}"

			if ! [[ "${ports}" =~ ^[0-9,\-]+$ ]]
			then
				echo -e "\n${fmt[blue]}[${fmt[color_red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid ports.\n"

				exit 1
			fi

			shift
		;;
		-w | --workflow)
			if [[ ! " ${workflows[@]} " =~ " ${2} " ]]
			then
				echo -e "\n${fmt[blue]}[${fmt[color_red]}✗${fmt[blue]}]${fmt[reset]} failed!...unknown workflow \"${2}\", see --workflows.\n"

				exit 1
			fi

			workflow=${2}

			shift
		;;
		--workflows)
			echo -e "Supported workflows:"

			echo
			for workflow in ${workflows[@]}
			do
				echo -e " ${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} ${workflow}"
			done
			echo

			exit 0
		;;
		-o | --output)
			output="${2:?'-o/--output requires an argument.'}"

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
			echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid option \"${1}\".\n"

			usage

			exit 1
		;;
	esac

	shift
done

if [ "${target}" == "__none__" ] && [ "${target_list}" == "__none__" ]
then
	echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...missing -t/--target or -l/--list argument.\n"

	exit 1
fi

if [ ! -d "${output}" ]
then
	mkdir -p "${output}"
fi

if [[ "$target" != "__none__" ]];
then
	discover "$target" "$ports" "$workflow"
fi

if [[ "$target_list" != "__none__" ]]
then
	while IFS= read -r target
	do
		if [[ -n "$target" ]]
		then
			discover "$target" "$ports" "$workflow"
		fi
	done < <(awk '!seen[$0]++' "$target_list")
fi

exit 0
