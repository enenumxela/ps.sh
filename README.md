# ps.sh

![Made with Bash](https://img.shields.io/badge/made%20with-Bash-0040ff.svg) ![Maintenance](https://img.shields.io/badge/maintained%3F-yes-0040ff.svg) [![open issues](https://img.shields.io/github/issues-raw/hueristiq/ps.sh.svg?style=flat&color=0040ff)](https://github.com/hueristiq/ps.sh/issues?q=is:issue+is:open) [![closed issues](https://img.shields.io/github/issues-closed-raw/hueristiq/ps.sh.svg?style=flat&color=0040ff)](https://github.com/hueristiq/ps.sh/issues?q=is:issue+is:closed) [![license](https://img.shields.io/badge/license-MIT-gray.svg?colorB=0040FF)](https://github.com/hueristiq/ps.sh/blob/master/LICENSE) [![author](https://img.shields.io/badge/twitter-@itshueristiq-0040ff.svg)](https://twitter.com/itshueristiq)

A wrapper around tools I use for port scanning - [smap](https://github.com/s0md3v/smap), [nmap](https://github.com/nmap/nmap), [naabu](https://github.com/projectdiscovery/naabu) & [masscan](https://github.com/robertdavidgraham/masscan) - the goal being reducing scan time, increasing scan efficiency and automating the workflow. 

## Installation

Run the installation script:

```bash
curl -s https://raw.githubusercontent.com/hueristiq/ps.sh/main/install.sh | bash -
```

## Usage

To display this script's help message, use the `-h` flag:

```bash
ps.sh -h
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
  -t, --target 		 target IP
 -tL, --target-list 	 target IPs list
  -w, --workflow 	 port scanning workflow (default: nmap2nmap)
                 	 (choices: smap2nmap, nmap2nmap, naabu2nmap or masscan2nmap)
  -k, --keep 		 keep each workflow's step results
 -oD, --output-dir 	 output directory path (default: .)
      --update 		 update this script & dependencies
  -h, --help 		 display this help message and exit

HAPPY HACKING :)
```

## Contribution

[Issues](https://github.com/hueristiq/ps.sh/issues) and [Pull Requests](https://github.com/hueristiq/ps.sh/pulls) are welcome!