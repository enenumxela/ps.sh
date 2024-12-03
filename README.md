# ps.sh

![Made with Bash](https://img.shields.io/badge/made%20with-Bash-0040ff.svg) ![Maintenance](https://img.shields.io/badge/maintained%3F-yes-0040ff.svg) [![open issues](https://img.shields.io/github/issues-raw/enenumxela/ps.sh.svg?style=flat&color=0040ff)](https://github.com/enenumxela/ps.sh/issues?q=is:issue+is:open) [![closed issues](https://img.shields.io/github/issues-closed-raw/enenumxela/ps.sh.svg?style=flat&color=0040ff)](https://github.com/enenumxela/ps.sh/issues?q=is:issue+is:closed) [![license](https://img.shields.io/badge/license-MIT-gray.svg?colorB=0040FF)](https://github.com/enenumxela/ps.sh/blob/master/LICENSE)

`ps.sh` is a bash script that automates the process of service discovery on specified target hosts. The aim of the scripts is reducing scan time, increasing scan efficiency and automating the workflow.

## Resource

* [Features](#features)
* [Installation](#installation)
* [Usage](#usage)
* [Contributing](#contributing)
* [Licensing](#licensing)
* [Credits](#credits)
	* [Contributors](#contributors)
	* [Dependencies](#dependencies)

## Features

* Automated port scanning using various workflows:
	* `nmap2nmap`: Use Nmap for both port discovery and service discovery.
	* `naabu2nmap`: Use Naabu for port discovery, followed by Nmap for service discovery.
	* `masscan2nmap`: Use Masscan for port discovery, followed by Nmap for service discovery.
* Service discovery to identify open services on the detected ports.
* Multiple target support - Scan a single target or a list of targets.
* Script auto-update support to keep the script and its dependencies up-to-date.

## Installation

To install `ps.sh`:

- ... with `curl`:

	```bash
	bash -c "$(curl -fsSL https://raw.githubusercontent.com/enenumxela/ps.sh/main/ps.sh)" -- --setup-script
	```

- ...with `wget`:

	```bash
	bash -c "$(wget -qO- https://raw.githubusercontent.com/enenumxela/ps.sh/main/ps.sh)" -- --setup-script
	```

After install, you can check if the script is installed and accessible globally by running:

```bash
ps.sh --help
```

## Usage

To display this script's help message, use the `-h` flag:

```bash
ps.sh -h
```

Here's what the help message looks like:

```text

                                          _
                          _ __  ___   ___| |__
                         | '_ \/ __| / __| '_ \
                         | |_) \__  _\__ \ | | |
                         | .__/|___(_)___/_| |_|
                         |_|              v1.0.0

              ---====| A Service Discovery Script |====---
                      ---====| with <3... |====---
               ---====| ...by Alex (@enenumxela) |====---

USAGE:
  ps.sh [OPTIONS]

OPTIONS:

 INPUT:
  -t, --target 				target IP
  -l, --list 				target IPs list file

 WORKFLOW:
  -w, --workflow 			discovery workflow (default: nmap2nmap)
      --workflows 			list supported workflows

 OUPUT:
  -k, --keep 				keep each workflow's step results
  -O, --output-directory 		output directory path (default: $PWD)

 SETUP:
      --setup-script 			setup ps.sh (install|update)
      --setup-dependencies 		setup ps.sh dependencies

 HELP:
  -h, --help 				display this help message


```

## Contributing

We welcome contributions! Feel free to submit [Pull Requests](https://github.com/enenumxela/ps.sh/pulls) or report [Issues](https://github.com/enenumxela/ps.sh/issues). For more details, check out the [contribution guidelines](https://github.com/enenumxela/ps.sh/blob/master/CONTRIBUTING.md).

## Licensing

This utility is licensed under the [MIT license](https://opensource.org/license/mit). You are free to use, modify, and distribute it, as long as you follow the terms of the license. You can find the full license text in the repository - [Full MIT license text](https://github.com/enenumxela/ps.sh/blob/master/LICENSE).

## Credits

### Contributors

A huge thanks to all the contributors who have helped make `ps.sh` what it is today!

[![contributors](https://contrib.rocks/image?repo=enenumxela/ps.sh&max=500)](https://github.com/enenumxela/ps.sh/graphs/contributors)

### Dependencies

[masscan](https://github.com/robertdavidgraham/masscan) ◇ [naabu](https://github.com/projectdiscovery/naabu) ◇ [nmap](https://github.com/nmap/nmap)