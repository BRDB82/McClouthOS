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
  -h            Print this help message

Description:
  This script installs McClouth OS components into the current system context.
  If no system_type is provided, the script attempts to read from the config file.

Examples:
  ${0##*/} server
  ${0##*/} workstation

EOF
  exit 1
}

# If no argument is passed, try to read from config
if [ -z "$1" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        system_type=$(grep '^system_type=' "$CONFIG_FILE" | cut -d'=' -f2)
    else
        echo "Error: No system type provided and config file not found."
        exit 1
    fi
else
    system_type="$1"
fi

case "$1" in
  server)
    echo "Installing server components..."
    #server install logic here
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
