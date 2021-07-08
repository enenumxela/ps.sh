#!/usr/bin/env bash

bold="\e[1m"
red="\e[31m"
cyan="\e[36m"
blue="\e[34m"
reset="\e[0m"
green="\e[32m"
yellow="\e[33m"
underline="\e[4m"

echo -e " [+] Running install script for subdomains.sh & its requirements.\n"

# tr sed awk tee nmap naabu masscan xmllint
sudo apt -qq -y curl nmap libxml2-utils libpcap-dev

# golang

if [ ! -x "$(command -v go)" ]
then
    version=1.15.7

    curl -sL https://golang.org/dl/go${version}.linux-amd64.tar.gz -o /tmp/go${version}.linux-amd64.tar.gz

    sudo tar -xzf /tmp/go${version}.linux-amd64.tar.gz -C /usr/local

    (grep -q "export PATH=\$PATH:/usr/local/go/bin" ~/.profile) || {
        export PATH=$PATH:/usr/local/go/bin
        echo "export PATH=\$PATH:/usr/local/go/bin" >> ~/.profile
    }

    (grep -q "export PATH=\$PATH:${HOME}/go/bin" ~/.profile) || {
        export PATH=$PATH:${HOME}/go/bin
        echo "export PATH=\$PATH:${HOME}/go/bin" >> ~/.profile
    }

    source ~/.profile
fi

# naabu

GO111MODULE=on go get -v github.com/projectdiscovery/naabu/v2/cmd/naabu

# ps.sh

script_path="${script_directory}/ps.sh"

if [ -f "${script_path}" ]
then
    rm ${script_path}
fi

curl -sL https://raw.githubusercontent.com/enenumxela/ps.sh/main/ps.sh -o ${script_path}
chmod u+x ${script_path}