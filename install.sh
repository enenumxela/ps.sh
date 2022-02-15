#!/usr/bin/env bash

bold="\e[1m"
red="\e[31m"
cyan="\e[36m"
blue="\e[34m"
reset="\e[0m"
green="\e[32m"
yellow="\e[33m"
underline="\e[4m"

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

# Banner
echo -e ${blue}${bold}"
                 _
 _ __  ___   ___| |__
| '_ \/ __| / __| '_ \\
| |_) \__  ${red}_${blue}\__ \ | | |
| .__/|___${red}(_)${blue}___/_| |_| ${yellow}v1.0.0${blue}
|_|
"${reset}

# tr sed awk tee nmap naabu masscan xmllint
sudo apt install -y -qq libxml2-utils 

# golang

if [ ! -x "$(command -v go)" ]
then
	version=1.17.6

	echo -e "\n [+] go${version}\n"

	eval ${DOWNLOAD_CMD} https://golang.org/dl/go${version}.linux-amd64.tar.gz > /tmp/go${version}.linux-amd64.tar.gz
	# curl -sL https://golang.org/dl/go${version}.linux-amd64.tar.gz -o /tmp/go${version}.linux-amd64.tar.gz

	sudo tar -xzf /tmp/go${version}.linux-amd64.tar.gz -C /usr/local
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

sudo apt install -y -qq nmap

# naabu

echo -e "\n [+] naabu\n"

sudo apt install -y -qq libpcap-dev
go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest

# masscan

echo -e "\n [+] masscan\n"

sudo apt install -y -qq masscan

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

# curl -sL https://raw.githubusercontent.com/enenumxela/ps.sh/main/ps.sh -o ${script_path}
chmod u+x ${script_path}