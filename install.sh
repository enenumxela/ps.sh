#!/usr/bin/env bash

RED="\e[31m"
CYAN="\e[36m"
BLUE="\e[34m"
GREEN="\e[32m"
YELLOW="\e[33m"

BOLD="\e[1m"
RESET="\e[0m"
UNDERLINE="\e[4m"

# Banner
echo -e ${BLUE}${BOLD}"
                 _
 _ __  ___   ___| |__
| '_ \/ __| / __| '_ \\
| |_) \__  ${RED}_${BLUE}\__ \ | | |
| .__/|___${RED}(_)${BLUE}___/_| |_| ${YELLOW}v1.0.0${BLUE}
|_|
"${RESET}

if [ "${SUDO_USER:-$USER}" != "${USER}" ]
then
	echo -e "${BLUE}[${RED}-${BLUE}]${RESET} failed!...ps.sh called with sudo!\n"
	exit 1
fi

CMD_PREFIX=

if [ ${UID} -gt 0 ] && [ -x "$(command -v sudo)" ]
then
	CMD_PREFIX="sudo"
elif [ ${UID} -gt 0 ] && [ ! -x "$(command -v sudo)" ]
then
	echo -e "${BLUE}[${RED}-${BLUE}]${RESET} failed!...\`sudo\` command not found!\n"
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
	echo "${BLUE}[${RED}-${BLUE}]${RESET} Could not find wget/cURL" >&2
	exit 1
fi

# tr sed awk tee nmap naabu masscan xmllint
eval ${CMD_PREFIX} apt-get install -y -qq libxml2-utils libpcap-dev

# golang

if [ ! -x "$(command -v go)" ] && [ ! -x "$(command -v /usr/local/go/bin/go)" ]
then
	version=1.17.6

	echo -e "\n [+] go${version}\n"

	eval ${DOWNLOAD_CMD} https://golang.org/dl/go${version}.linux-amd64.tar.gz > /tmp/go${version}.linux-amd64.tar.gz

	eval ${CMD_PREFIX} tar -xzf /tmp/go${version}.linux-amd64.tar.gz -C /usr/local
fi

(grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.profile) || {
	export PATH=$PATH:/usr/local/go/bin
	echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
}

(grep -q "export PATH=\$PATH:${HOME}/go/bin" ~/.profile) || {
	export PATH=$PATH:${HOME}/go/bin
	echo "export PATH=\$PATH:${HOME}/go/bin" >> ~/.profile
}

source ~/.profile

# nmap

echo -e "\n [+] nmap\n"

eval ${CMD_PREFIX} apt-get install -y -qq nmap

# naabu

echo -e "\n [+] naabu\n"

go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# masscan

echo -e "\n [+] masscan\n"

eval ${CMD_PREFIX} apt-get install -y -qq masscan

script_directory="${HOME}/.local/bin"

if [ ! -d ${script_directory} ]
then
	mkdir -p ${script_directory}
fi

# ps.sh

echo -e "\n [+] ps.sh\n"

script_path="${script_directory}/ps.sh"

if [ -e "${script_path}" ]
then
	rm ${script_path}
fi

eval ${DOWNLOAD_CMD} https://raw.githubusercontent.com/enenumxela/ps.sh/main/ps.sh > ${script_path}

chmod u+x ${script_path}