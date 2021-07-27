# ps.sh

![Made with Bash](https://img.shields.io/badge/made%20with-Bash-0040ff.svg) ![Maintenance](https://img.shields.io/badge/maintained%3F-yes-0040ff.svg) [![open issues](https://img.shields.io/github/issues-raw/enenumxela/ps.sh.svg?style=flat&color=0040ff)](https://github.com/enenumxela/ps.sh/issues?q=is:issue+is:open) [![closed issues](https://img.shields.io/github/issues-closed-raw/enenumxela/ps.sh.svg?style=flat&color=0040ff)](https://github.com/enenumxela/ps.sh/issues?q=is:issue+is:closed) [![license](https://img.shields.io/badge/license-MIT-gray.svg?colorB=0040FF)](https://github.com/enenumxela/ps.sh/blob/master/LICENSE) [![author](https://img.shields.io/badge/twitter-@enenumxela-0040ff.svg)](https://twitter.com/enenumxela)

A wrapper around tools I use for port scanning - [nmap](https://github.com/nmap/nmap), [naabu](https://github.com/projectdiscovery/naabu) & [masscan](https://github.com/robertdavidgraham/masscan) - the goal being reducing scan time, increasing scan efficiency and automating the workflow. 

## Installation

To get the script clone this repository:

```bash
$ git clone https://github.com/enenumxela/ps.sh.git
```

## Usage

To display this script's help message, use the `-h` flag:

```bash
./ps.sh -h
```

```text
                 _
 _ __  ___   ___| |__
| '_ \/ __| / __| '_ \
| |_) \__  _\__ \ | | |
| .__/|___(_)___/_| |_| v1.0.0
|_|

 USAGE:
   ps.sh [OPTIONS]

Options:
   -t, --target 	 target to enumerate
   -w, --workflow 	 port scanning workflow [nmap2nmap|naabu2nmap|masscan2nmap]
                  	 (default: nmap2nmap)
  -oD, --output-dir 	 output directory path
   -k, --keep 		 keep each tool's temp results
       --setup 		 setup requirements for this script
   -h, --help 		 display this help message and exit

 HAPPY HACKING :)

```

## Contribution

[Issues](https://github.com/enenumxela/ps.sh/issues) and [Pull Requests](https://github.com/enenumxela/ps.sh/pulls) are welcome!