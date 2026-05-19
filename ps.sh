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

print_banner() {
echo -e ${fmt[bold]}${fmt[blue]}"
                                                  _
                                  _ __  ___   ___| |__
                                 | '_ \/ __| / __| '_ \\
                                 | |_) \__  ${fmt[red]}_${fmt[blue]}\__ \ | | |
                                 | .__/|___${fmt[red]}(_)${fmt[blue]}___/_| |_|
                                 |_|                    ${fmt[yellow]}[${fmt[red]} v1.0.0 ${fmt[yellow]}]${fmt[green]}

<>--------------------------<><> ${fmt[blue]}A Port Scanning Script.${fmt[green]} <><>--------------------------<>
"${fmt[reset]}
}

print_help_msg() {
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
	\r   -h, --help                display this help message
	\r
EOF
}

setup_dependencies() {
	echo -e " ${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} Setting up...\n"

	local pkgs=()

	command -v nmap &>/dev/null || pkgs+=(nmap)
	command -v masscan &>/dev/null || pkgs+=(masscan)
	command -v xmllint &>/dev/null || pkgs+=(libxml2-utils)

	if [[ ${#pkgs[@]} -ne 0 ]]
	then
		${CMD_PREFIX} apt-get update -qq
		${CMD_PREFIX} apt-get install -y -qq "${pkgs[@]}"
	else
		echo -e "    ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...all is set."
	fi

	echo -e "\n ${fmt[blue]}[${fmt[green]}✓${fmt[blue]}]${fmt[reset]} Setting up...done!\n"
}

is_IP_valid() {
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
	local IP="$1"
	local ports="$2"

	local output="$3"

	${CMD_PREFIX} nmap --min-rate 1000 -sS -T4 --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p "${ports}" -Pn "${IP}" -oX "${output}"
}

run_masscan_open_ports_discovery() {
	local IP="$1"
	local ports="$2"

	local output="$3"

	${CMD_PREFIX} masscan --ports "${ports}" "${IP}" --max-rate 1000 -oX "${output}"
}

xml_extract_open_ports() {
	local f="$1"

	xmllint --xpath '//port/state[@state="open"]/../@portid' "${f}" 2>/dev/null | grep -oP '"\K[^"]+' | sort -nu
}

run_nmap_open_services_discovery() {
	local IP="$1"
	local ports="$2"

	local output="$3"

	${CMD_PREFIX} nmap -T4 -A --max-retries 2 -p "${ports}" -Pn "${IP}" -oA "${output}"
}

run_discovery() {
	local IP=$1
	local ports=$2
	local workflow=$3

	if ! is_IP_valid "${IP}"
	then
		echo -e "    ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...invalid IP \"${IP}\".\n"

		return 0
	fi

	echo -e "${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} Scanning ${fmt[bold]}${fmt[underline]}${IP}${fmt[reset]}...\n"

	local -a discovered_open_ports=()

	local discovered_ports_discovery_output=""
	local discovered_services_discovery_output="${output}/${IP}"

	echo -e "    ${fmt[blue]}[${fmt[green]}>${fmt[blue]}]${fmt[reset]} Port(s) Discovery\n"

	case "${workflow}" in
		nmap2nmap)
			discovered_ports_discovery_output="${output}/${IP}-nmap-port-discovery.xml"

			if [[ -s "${discovered_ports_discovery_output}" ]]
			then
				echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found."
			else
				run_nmap_open_ports_discovery "${IP}" "${ports}" "${discovered_ports_discovery_output}"
			fi

			if [[ -s "${discovered_ports_discovery_output}" ]]
			then
				mapfile -t discovered_open_ports < <(xml_extract_open_ports "${discovered_ports_discovery_output}")
			fi
			;;
		masscan2nmap)
			discovered_ports_discovery_output="${output}/${IP}-masscan-port-discovery.xml"

			if [[ -s "${discovered_ports_discovery_output}" ]]
			then
				echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found."
			else
				run_masscan_open_ports_discovery "${IP}" "${ports}" "${discovered_ports_discovery_output}"
			fi

			if [[ -s "${discovered_ports_discovery_output}" ]]
			then
				mapfile -t discovered_open_ports < <(xml_extract_open_ports "${discovered_ports_discovery_output}")
			fi
			;;
	esac

	echo -e "\n    ${fmt[blue]}[${fmt[green]}>${fmt[blue]}]${fmt[reset]} Service(s) Discovery\n"

	if [[ ! -s "${discovered_services_discovery_output}.xml" ]]
	then
		if [[ ${#discovered_open_ports[@]} -eq 0 ]]
		then
			echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...no open ports found."
		else
			mapfile -t discovered_open_ports < <(printf '%s\n' "${discovered_open_ports[@]}" | sort -nu)

			local discovered_open_ports_csv

			discovered_open_ports_csv="$(IFS=','; printf '%s' "${discovered_open_ports[*]}")"

			run_nmap_open_services_discovery "${IP}" "${discovered_open_ports_csv}" "${discovered_services_discovery_output}"
		fi
	else
		echo -e "        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found."
	fi

	echo -e "\n${fmt[blue]}[${fmt[green]}✓${fmt[blue]}]${fmt[reset]} Scanning ${fmt[bold]}${fmt[underline]}${IP}${fmt[reset]}...done!\n"
}

is_ports_valid() {
	local ports="$1"

	if ! [[ "${ports}" =~ ^[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$ ]]
	then
		echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid port format.\n"

		return 1
	fi

	local tokens token start end port

	IFS=',' read -ra tokens <<< "${ports}"

	for token in "${tokens[@]}"
	do
		if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]
		then
			start=${BASH_REMATCH[1]}
			end=${BASH_REMATCH[2]}

			start=$((10#$start))
			end=$((10#$end))

			if (( start > 65535 || end > 65535 || start > end ))
			then
				echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid port range \"${start}-${end}\".\n"

				return 1
			fi
		else
			port=$((10#$token))

			if (( port > 65535 ))
			then
				echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid port \"${port}\".\n"

				return 1
			fi
		fi
	done

	return 0
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

print_banner

if [[ $# -eq 0 ]]
then
	print_help_msg

	exit 0
fi

if [[ -n "${SUDO_USER:-}" ]]
then
	echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...${0##*/} shouldn't be run with \`sudo\`, it escalates privileges internally when needed.\n"

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
				echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...missing or empty IPs file.\n"

				exit 1
			fi

			shift
		;;
		-p | --ports)
			ports="${2:?'-p/--ports requires an argument.'}"

			if ! is_ports_valid "${ports}"
			then
				exit 1
			fi

			shift
		;;
		-w | --workflow)
			if [[ ! " ${workflows[@]} " =~ " ${2} " ]]
			then
				echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...unknown workflow \"${2}\", see --workflows.\n"

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
			setup_dependencies

			exit 0
		;;
		-h | --help)
			print_help_msg

			exit 0
		;;
		*)
			echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid option \"${1}\".\n"

			print_help_msg

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
	run_discovery "$target" "$ports" "$workflow"
fi

if [[ "$target_list" != "__none__" ]]
then
	while IFS= read -r target
	do
		if [[ -n "$target" ]]
		then
			run_discovery "$target" "$ports" "$workflow"
		fi
	done < <(awk '!seen[$0]++' "$target_list")
fi

exit 0
