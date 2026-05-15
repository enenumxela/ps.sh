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
	\r   -j, --jobs                parallel nc jobs, nc2nmap only (default: ${fmt[underline]}${nc_jobs}${fmt[reset]})
	\r   -o, --output              output directory (default: ${fmt[underline]}${output}${fmt[reset]})
	\r       --setup               install required dependencies
	\r   -h, --help                display this help
	\r
EOF
}

setup() {
	echo -e " ${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} Setting up..."

	local pkgs=()

	command -v nc &>/dev/null || pkgs+=(netcat-openbsd)
	command -v nmap &>/dev/null || pkgs+=(nmap)
	command -v masscan &>/dev/null || pkgs+=(masscan)
	command -v xmllint &>/dev/null || pkgs+=(libxml2-utils)

	if [[ ${#pkgs[@]} -ne 0 ]]
	then
		$CMD_PREFIX apt-get update -qq
		$CMD_PREFIX apt-get install -y -qq "${pkgs[@]}"
	fi

	echo -e " ${fmt[blue]}[${fmt[green]}✓${fmt[blue]}]${fmt[reset]} Setting up...done!"
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

ports_expand() {
	local ports="$1"

	IFS=',' read -ra parts <<< "$ports"

	local part start end p

	for part in "${parts[@]}"
	do
		if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]
		then
			start="${BASH_REMATCH[1]}"
			end="${BASH_REMATCH[2]}"

			if (( start > end ))
			then
				echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid port range \"${start}-${end}\".\n"

				exit 1
			fi

			for (( p = start; p <= end; p++ ))
			do
				printf '%d\n' "$p"
			done
		elif [[ "$part" =~ ^[0-9]+$ ]]
		then
			printf '%d\n' "$part"
		else
			echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...invalid port specification \"${part}\".\n"

			exit 1
		fi
	done
}

run_nc_open_ports_discovery() {
	local nc_target="$1"
	local nc_ports="$2"
	local nc_output="$3"

	local -a nc_ports_list

	mapfile -t nc_ports_list < <(ports_expand "${nc_ports}")

	local nc_tmp_output

	nc_tmp_output="$(mktemp)"

	local nc_lock_file="${nc_tmp_output}.lock"

	touch "${nc_lock_file}"

	local -a pids=()

	_nc_cleanup() {
		[[ "${#pids[@]}" -gt 0 ]] && kill "${pids[@]}" 2>/dev/null || true
		rm -f "${nc_tmp_output}" "${nc_lock_file}"
	}

	trap _nc_cleanup INT TERM

	local running=0

	_nc_probe() {
		local _nc_target="$1"
		local _nc_port="$2"
		local _nc_tmp_output="$3"
		local _nc_lock="$4"

		if timeout 3 nc -z -w 2 "${_nc_target}" "${_nc_port}" &>/dev/null
		then
			(
				flock --exclusive 200
				printf '%d\n' "${_nc_port}"
			) 200>>"${_nc_lock}" >> "${_nc_tmp_output}"
		fi
	}

	for nc_port in "${nc_ports_list[@]}"
	do
		_nc_probe "${nc_target}" "${nc_port}" "${nc_tmp_output}" "${nc_lock_file}" &

		pids+=($!)

		(( ++running ))

		if (( running >= nc_jobs ))
		then
			wait -n 2>/dev/null || true

			(( running-- ))
		fi
	done

	wait "${pids[@]}" 2>/dev/null || true

	trap - INT TERM

	if [[ -s "${nc_tmp_output}" ]]
	then
		sort -nu "${nc_tmp_output}" > "${nc_output}"
	fi

	rm -f "${nc_tmp_output}" "${nc_lock_file}"
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
		echo -e "\n${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...invalid IP \"${target}\".\n"

		return 0
	fi

	echo -e "\n${fmt[blue]}[${fmt[green]}+${fmt[blue]}]${fmt[reset]} Scanning ${fmt[bold]}${fmt[underline]}${target}${fmt[reset]}...\n"

	local -a open_ports=()

	local port_s_discovery_output=""
	local service_s_discovery_output="${output}/${target}"

	echo -e "    ${fmt[blue]}[${fmt[green]}>${fmt[blue]}]${fmt[reset]} Port(s) Discovery\n"

	case "${workflow}" in
		nc2nmap)
			port_s_discovery_output="${output}/${target}-nc-port-discovery.txt"

			if [[ -s "${port_s_discovery_output}" ]]
			then
				echo -e "\n        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found.\n"
			else
				run_nc_open_ports_discovery "${target}" "${ports}" "${port_s_discovery_output}"
			fi

			if [[ -s "${port_s_discovery_output}" ]]
			then
				mapfile -t open_ports < "${port_s_discovery_output}"
			fi
			;;
		nmap2nmap)
			port_s_discovery_output="${output}/${target}-nmap-port-discovery.xml"

			if [[ -s "${port_s_discovery_output}" ]]
			then
				echo -e "\n        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found.\n"
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
				echo -e "\n        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found.\n"
			else
				run_masscan_open_ports_discovery "${target}" "${ports}" "${port_s_discovery_output}"
			fi

			if [[ -s "${port_s_discovery_output}" ]]
			then
				mapfile -t open_ports < <(xml_extract_open_ports "${port_s_discovery_output}")
			fi
			;;
	esac

	echo -e "\n     ${fmt[blue]}[${fmt[green]}>${fmt[blue]}]${fmt[reset]} Service(s) Discovery\n"

	if [[ ! -s "${service_s_discovery_output}.xml" ]]
	then
		if [[ ${#open_ports[@]} -eq 0 ]]
		then
			echo -e "\n        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...no open ports found.\n"
		else
			mapfile -t open_ports < <(printf '%s\n' "${open_ports[@]}" | sort -nu)

			local open_ports_csv

			open_ports_csv="$(IFS=','; printf '%s' "${open_ports[*]}")"

			$CMD_PREFIX nmap -T4 -A --max-retries 2 -p "${open_ports_csv}" -Pn "${target}" -oA "${service_s_discovery_output}"
		fi
	else
		echo -e "\n        ${fmt[blue]}[${fmt[yellow]}!${fmt[blue]}]${fmt[reset]} skipped!...previous results found.\n"
	fi

	echo -e "\n${fmt[blue]}[${fmt[green]}✓${fmt[blue]}]${fmt[reset]} Scanning ${fmt[bold]}${fmt[underline]}${target}${fmt[reset]}...done!\n"
}

readonly workflows=(
	nc2nmap
	nmap2nmap
	masscan2nmap
)

target="__none__"
target_list="__none__"

ports="0-65535"

workflow="nmap2nmap"

nc_jobs="$(( $(nproc 2>/dev/null || echo 4) * 10 ))"

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
		-j | --jobs)
			nc_jobs="${2:?'-j/--jobs requires an argument.'}"

			if ! [[ "${nc_jobs}" =~ ^[0-9]+$ ]] || (( nc_jobs < 1 ))
			then
				echo -e "\n${fmt[blue]}[${fmt[red]}✗${fmt[blue]}]${fmt[reset]} failed!...jobs must be a positive integer.\n"

				exit 1
			fi

			shift
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