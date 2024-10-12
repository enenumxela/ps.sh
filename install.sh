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
                        | .__/|___${RED}(_)${BLUE}___/_| |_|
                        |_|              ${YELLOW}v1.0.0${BLUE}

          ---====| A Port & Service Discovery Script |====---"${RESET}

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

if [ ! -x "$(command -v go)" ]
then
	if [ ! -f /tmp/go1.23.1.linux-amd64.tar.gz ]
	then
		curl -sL https://golang.org/dl/go1.23.1.linux-amd64.tar.gz -o /tmp/go1.23.1.linux-amd64.tar.gz
	fi
	if [ -f /tmp/go1.23.1.linux-amd64.tar.gz ]
	then
		tar -xzf /tmp/go1.23.1.linux-amd64.tar.gz -C /usr/local

		rm -rf /tmp/go1.23.1.linux-amd64.tar.gz
	fi
fi

(grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.profile) || {
	echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
}
(grep -q "export PATH=\$PATH:\${HOME}/go/bin" ~/.profile) || {
	echo "export PATH=\$PATH:\${HOME}/go/bin" >> ~/.profile
}

source ${HOME}/.profile

# smap

echo -e "\n [+] smap\n"

go install -v github.com/s0md3v/smap/cmd/smap@latest

# nmap

echo -e "\n [+] nmap\n"

eval ${CMD_PREFIX} apt-get install -y -qq nmap

# naabu

echo -e "\n [+] naabu\n"

go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# masscan

echo -e "\n [+] masscan\n"

eval ${CMD_PREFIX} apt-get install -y -qq masscan

# ps.sh

echo -e "\n [+] ps.sh\n"

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

chmod u+x ${script_path}