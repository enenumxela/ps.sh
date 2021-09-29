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
output_directory="."
port_scan_workflow="nmap2nmap"
port_scan_workflows=(nmap2nmap naabu2nmap masscan2nmap)

# Function to display the script usage
display_usage() {
	while read -r line
	do
		printf "%b\n" "${line}"
	done <<-EOF
	\r USAGE:
	\r   ${script_file_name} [OPTIONS]

	\rOptions:
	\r   -t, --target \t target to enumerate
	\r   -w, --workflow \t port scanning workflow [nmap2nmap|naabu2nmap|masscan2nmap]
	\r                  \t (default: ${underline}${port_scan_workflow}${reset})
	\r  -oD, --output-dir \t output directory path
	\r   -k, --keep \t\t keep each tool's temp results
	\r       --setup \t\t setup requirements for this script
	\r   -h, --help \t\t display this help message and exit

	\r ${red}${bold}HAPPY HACKING ${yellow}:)${reset}

EOF
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

if [ "${UID}" -gt 0 ]
then
	echo -e "${blue}[${red}-${blue}]${reset} root privileges required!\n"
	exit 1
fi

# ensure target(s) is provided
if [ ${target} == False ]
then
	echo -e "${blue}[${red}-${blue}]${reset} failed! argument -t/--target is Required!\n"
	exit 1
fi

echo -e "[+] open port(s) discovery\n"

# nmap2nmap workflow

nmap_port_discovery_output="${output_directory}/${target}-nmap-port-discovery.xml"

if [ "${port_scan_workflow}" == "nmap2nmap" ]
then
	nmap -Pn -sS -T4 -n --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit -p0- ${target} -oX ${nmap_port_discovery_output}

	if [ ! -f ${nmap_port_discovery_output} ]
	then 
		skip=True
	fi
fi

# naabu2nmap workflow

naabu_port_discovery_output="${output_directory}/${target}-naabu-port-discovery.txt"

if [ "${port_scan_workflow}" == "naabu2nmap" ]
then
	naabu -host ${target} -p - -silent | tee ${naabu_port_discovery_output}

	if [ $(wc -l < ${naabu_port_discovery_output}) -eq 0 ]
	then 
		skip=True

		echo -e "    [-] no open port discovered!"

		rm -rf ${port_discovery_output_dir}
	fi
fi

service_discovery_output="${output_directory}/${target}.xml"

# nmap2nmap workflow
if [ "${port_scan_workflow}" == "nmap2nmap" ]
then
	if [ ! -f ${nmap_port_discovery_output} ]
	then
		port_discovery
	fi

	open_ports_space_separeted="$(xmllint --xpath '//port/state[@state = "open" or @state = "closed" or @state = "unfiltered"]/../@portid' ${nmap_port_discovery_output} | awk -F\" '{ print $2 }' | tr '\n' ' ' |sed -e 's/[[:space:]]*$//')"

	if [ ${#open_ports_space_separeted} -gt 0 ]
	then
		echo -e "\n[+] service(s) discovery\n"

		open_ports_comma_separeted=${open_ports_space_separeted// /,}

		nmap -Pn -sS -sV -T4 -n -p ${open_ports_comma_separeted} ${target} -oX ${service_discovery_output}
	fi
fi

# naabu2nmap workflow
if [ "${port_scan_workflow}" == "naabu2nmap" ]
then
	if [ ! -f ${naabu_port_discovery_output} ]
	then
		port_discovery
	fi

	echo -e "\n[+] service(s) discovery\n"

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

		nmap -Pn -sS -sV -T4 -n -p ${ports_string// /,} ${target} -oX ${service_discovery_output}
	fi
fi

if [ ${keep} == False ]
then
	rm -rf ${output_directory}/*-port-discovery.*
fi

exit 0