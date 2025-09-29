#!/bin/bash

echo -ne "
███╗   ███╗ ██████╗ ██████╗██╗      ██████╗ ██╗   ██╗████████╗██╗  ██╗     ██████╗ ███████╗
████╗ ████║██╔════╝██╔════╝██║     ██╔═══██╗██║   ██║╚══██╔══╝██║  ██║    ██╔═══██╗██╔════╝
██╔████╔██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ███████║    ██║   ██║███████╗
██║╚██╔╝██║██║     ██║     ██║     ██║   ██║██║   ██║   ██║   ██╔══██║    ██║   ██║╚════██║
██║ ╚═╝ ██║╚██████╗╚██████╗███████╗╚██████╔╝╚██████╔╝   ██║   ██║  ██║    ╚██████╔╝███████║
╚═╝     ╚═╝ ╚═════╝ ╚═════╝╚══════╝ ╚═════╝  ╚═════╝    ╚═╝   ╚═╝  ╚═╝     ╚═════╝ ╚══════╝
Extended installation [Server/Workstation]

--------------------------------------------------------------------------------------------
             Automated McClouth OS Extended Installer (powered by Rocky)
--------------------------------------------------------------------------------------------
"
CONFIG_FILE="/etc/mcclouth/mcclouth.conf"

usage() {
  cat <<EOF
Usage: ${0##*/} [system_type]

Arguments:
  server        Install server components
  workstation   Install workstation environment

Options:
  --help        Print this help message
  --update      Update to the latest version

Description:
  This script installs McClouth OS components into the current system context.
  If no system_type is provided, the script attempts to read from the config file.

Examples:
  ${0##*/} server
  ${0##*/} workstation

EOF
  exit 1
}

server_install() {
if { command -v systemd-detect-virt &> /dev/null && [ "$(systemd-detect-virt)" = "none" ]; } \
   && { ! command -v dmidecode &> /dev/null || ! [[ "$(dmidecode -s system-product-name 2>/dev/null)" =~ (VMware|KVM|HVM|Bochs|QEMU) ]]; } \
   && ! grep -qi hypervisor /proc/cpuinfo; then
	echo "Real hardware"

	#CPU information
	if [ "$(nproc)" -lt 12 ]; then
		echo "System doesn't have enough cores."
		exit 1
	fi

	#Memory Information
	total_mem=$(free -m | awk '/^Mem:/ { print $2 }')
	total_mem=$((total_mem / 1024 / 1024))
	
	if [ "$total_mem" -lt 32 ]; then
		echo "System needs at least 32 GB of RAM."
		exit 1
	fi
else
  echo "Virtual hardware"
fi
}

# If no argument is passed, try to read from config
if [ -z "$1" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        system_type=$(grep '^system_type=' "$CONFIG_FILE" | cut -d'=' -f2)
    else
        echo "Error: No system type provided and config file not found."
        usage
        exit 1
    fi
    usage
    exit 1
elif [ "$1" == "--update" ]; then
	curl -fsSL "https://raw.githubusercontent.com/BRDB82/McClouthOS/main/Rocky/mcclouth-setup.sh" -o "/usr/bin/mcclouth-setup.new" || {
	echo "update failed"
	rm "/usr/bin/mcclouth-setup.new"
	exit 1
	}
	chmod +x "/usr/bin/mcclouth-setup.new"
	mv -f "/usr/bin/mcclouth-setup.new" "/usr/bin/mcclouth-setup"
	exit 1
else
    system_type="$1"
fi

case "$1" in
  server)
    echo "Installing server components..."
    server_install
    ;;
  workstation)
    echo "Installing workstation environment..."
    #workstation install logic here
    ;;
  *)
    echo "Unknown system type: '$system_type'"
    exit 1
  ;;
esac
