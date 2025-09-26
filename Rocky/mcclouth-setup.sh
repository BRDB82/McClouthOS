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
